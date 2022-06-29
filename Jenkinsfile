pipeline {
    agent any

    environment {
      UPDATE_HC_UUID = credentials('UPDATE_HC_UUID')
      OPENVPN_PASSWORD = credentials('OPENVPN_PASSWORD')
      OPENVPN_USERNAME = credentials('OPENVPN_USERNAME')
      DRONE_GITHUB_CLIENT_ID = credentials('DRONE_GITHUB_CLIENT_ID')
      DRONE_GITHUB_CLIENT_SECRET = credentials('DRONE_GITHUB_CLIENT_SECRET')
      DRONE_RPC_SECRET = credentials('DRONE_RPC_SECRET')
      DRONE_USER_FILTER = credentials('DRONE_USER_FILTER')
      DRONE_USER_CREATE = credentials('DRONE_USER_CREATE')
      CF_API_EMAIL = credentials('CF_API_EMAIL')
      CF_API_KEY = credentials('CF_API_KEY')
      CLIENT_ID = credentials('CLIENT_ID')
      CLIENT_SECRET = credentials('CLIENT_SECRET')
      SECRET = credentials('SECRET')
      INSIDE_DOCKER = 'true'
    }
    stages {
        stage('Deploy') {
            steps {
                echo 'Running deployment script..'
                sh '''
                  if ! [ -x "$(command -v docker)" ]; then
                    echo "docker could not be found; will install"
                    curl -fsSL https://get.docker.com -o get-docker.sh
                    grep -v "sleep" get-docker.sh > get-docker.tmp.sh && mv -f get-docker.tmp.sh get-docker.sh
                    sh get-docker.sh
                  else
                    echo "docker found; skipping installation"
                  fi
                  '''
                sh './scripts/deploy.sh'
            }
        }
    }
}
