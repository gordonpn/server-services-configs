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
                    curl -fsSL https://get.docker.com -o get-docker.sh
                    grep -v "sleep" get-docker.sh > get-docker.tmp.sh && mv -f get-docker.tmp.sh get-docker.sh
                    sh get-docker.sh
                  fi
                  '''
                sh 'docker compose --help'
                // sh './scripts/deploy.sh'
            }
        }
    }
}
