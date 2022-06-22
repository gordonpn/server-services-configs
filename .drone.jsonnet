local notification(message) = {
  kind: 'pipeline',
  name: 'notification %(message)s' % { message: message },
  type: 'docker',
  steps: [
    {
      name: 'notification',
      image: 'plugins/slack',
      failure: 'ignore',
      settings: {
        channel: 'drone-ci',
        webhook: {
          from_secret: 'SLACK_WEBHOOK_URL',
        },
        template: |||
          %(message)s
          {{ uppercasefirst build.event }} on branch {{ build.branch }} from repo {{repo.name}}
          <{{ build.link }}|Visit build #{{build.number}} page ➡️>
        ||| % { message: message },
      },
    },
  ],
};

local terraform = {
  kind: 'pipeline',
  name: 'terraform',
  type: 'docker',
  steps: [
    {
      name: 'terraform apply',
      image: 'hashicorp/terraform',
      environment: {
        CLOUDFLARE_EMAIL: {
          from_secret: 'CLOUDFLARE_EMAIL',
        },
        CLOUDFLARE_API_TOKEN: {
          from_secret: 'CLOUDFLARE_API_TOKEN',
        },
      },
      commands: [
        'cd ./terraform',
        'terraform -v',
        'terraform init',
        'terraform validate',
        'terraform apply -auto-approve',
      ],
    },
  ],
};

[
  notification('Build starting'),
  terraform,
  notification('Build finished'),
]
