local push_trigger = {
  trigger: { event: ['push'] },
};

local cron_trigger = {
  trigger: {
    event: ['cron'],
    cron: ['daily'],
  },
};

local failure_notification = {
  name: 'failure notification',
  image: 'plugins/slack',
  when: { status: ['failure'] },
  failure: 'ignore',
  settings: {
    channel: 'drone-ci',
    webhook: {
      from_secret: 'SLACK_WEBHOOK_URL',
    },
    template: |||
      Deploy failed
      Commit: <https://github.com/{{ repo.owner }}/{{ repo.name }}/commit/{{ build.commit }}|{{ truncate build.commit 8 }}>
      Branch: <https://github.com/{{ repo.owner }}/{{ repo.name }}/commits/{{ build.branch }}|{{ build.branch }}>
      Author: {{ build.author }}
      <{{ build.link }}|Visit build #{{build.number}} page ➡️>
    |||,
  },
};

local deploy(name) = {
  kind: 'pipeline',
  type: 'docker',
  name: 'deploy %(name)s' % name,
  steps: [
    {
      name: 'deploy prod',
      image: 'docker:20.10.12',
      environment: {
        UPDATE_HC_UUID: { from_secret: 'UPDATE_HC_UUID' },
        OPENVPN_PASSWORD: { from_secret: 'OPENVPN_PASSWORD' },
        OPENVPN_USERNAME: { from_secret: 'OPENVPN_USERNAME' },
        DRONE_GITHUB_CLIENT_ID: { from_secret: 'DRONE_GITHUB_CLIENT_ID' },
        DRONE_GITHUB_CLIENT_SECRET: { from_secret: 'DRONE_GITHUB_CLIENT_SECRET' },
        DRONE_RPC_SECRET: { from_secret: 'DRONE_RPC_SECRET' },
        DRONE_USER_FILTER: { from_secret: 'DRONE_USER_FILTER' },
        DRONE_USER_CREATE: { from_secret: 'DRONE_USER_CREATE' },
        CF_API_EMAIL: { from_secret: 'CF_API_EMAIL' },
        CF_API_KEY: { from_secret: 'CF_API_KEY' },
        CLIENT_ID: { from_secret: 'CLIENT_ID' },
        CLIENT_SECRET: { from_secret: 'CLIENT_SECRET' },
        SECRET: { from_secret: 'SECRET' },
        DRONE_CI: true,
      },
      volumes: [{
        name: 'dockersock',
        path: '/var/run/docker.sock',
      }],
      commands: [
        'apk update && apk --no-cache add bash curl docker-compose && curl --version && bash --version && docker-compose version',
        '/bin/bash /drone/src/scripts/deploy.sh',
      ],
    },
    failure_notification,
  ],
  volumes: [{
    name: 'dockersock',
    host: { path: '/var/run/docker.sock' },
  }],
};

[
  cron_trigger + deploy('cron'),
  push_trigger + deploy('push'),
]
