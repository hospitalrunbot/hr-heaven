#!/bin/bash

run_as_heaven_user() {
  sudo su - heaven -c "$@"
}

useradd -m -d /home/heaven heaven -s /bin/bash -k /etc/skel -g 100 -G docker
run_as_heaven_user docker run -it --rm hello-world

run_as_heaven_user docker network create heaven

# Setup Databases
run_as_heaven_user docker run --name heaven-postgres -d --net heaven -e POSTGRES_USER=heaven postgres:latest
run_as_heaven_user docker run --name heaven-redis -d --net heaven redis:latest

# Setup application
run_as_heaven_user ssh-keygen -C heaven@hr-heaven-dev -f ~/.ssh/heaven_hr_heaven_dev_deploy_key -N""
run_as_heaven_user cat > /home/heaven/env.list <<EOS
# Configuration for Heaven. Restart the server whenever you edit this file.
# https://github.com/atmos/heaven/blob/master/doc/installation.md
DATABASE_URL=postgres://heaven@heaven-postgres/heaven
REDIS_PROVIDER=REDIS_CONTAINER_URL
REDIS_CONTAINER_URL=redis://heaven-redis:6379
GITHUB_TOKEN=
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
RAILS_ENV=production
SLACK_WEBHOOK_URL=
DEPLOYMENT_PRIVATE_KEY="Output of ~/.ssh/heaven_hr_heaven_dev_deploy_key but replace newlines with \n"
RAILS_SECRET_KEY_BASE=$(docker run --rm --net heaven --env-file ./env.list emdentec/heaven "rake" "secret")
EOS
run_as_heaven_user docker run --rm --net heaven --env-file ./env.list emdentec/heaven "rake" "db:migrate"
run_as_heaven_user docker run --name heaven --net heaven --publish 80:80 --env-file ./env.list -d emdentec/heaven
run_as_heaven_user docker run --name heaven-worker-1 --net heaven --env-file ./env.list -d emdentec/heaven "rake" "resque:work" "QUEUE=*"
run_as_heaven_user docker run --name heaven-worker-2 --net heaven --env-file ./env.list -d emdentec/heaven "rake" "resque:work" "QUEUE=*"
run_as_heaven_user docker ps
