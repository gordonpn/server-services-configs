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
      name: 'terraform',
      image: 'ubuntu',
      environment: {
        CLOUDFLARE_EMAIL: {
          from_secret: 'CLOUDFLARE_EMAIL',
        },
        CLOUDFLARE_API_TOKEN: {
          from_secret: 'CLOUDFLARE_API_TOKEN',
        },
      },
      commands: [
        'apt-get update && sudo apt-get install curl',
        'curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -',
        'apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"',
        'apt-get update && sudo apt-get install terraform',
        'cd ./terraform',
        'terraform -v',
        'terraform init',
        'terraform validate',
        'terraform plan',
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
