pipeline {
    agent any

    stages {
        stage('Deploy') {
            steps {
                echo 'Running deployment script..'
                sh 'export INSIDE_DOCKER=true'
                sh '''
                  if ! command -v docker &>/dev/null; then
                    echo "docker could not be found"
                    curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
                  fi
                  '''
                sh 'command -v docker && docker -v'
                sh 'command -v docker-compose && docker-compose -v'
                // sh './scripts/deploy.sh'
            }
        }
    }
}
