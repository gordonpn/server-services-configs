pipeline {
    agent any

    stages {
        stage('Deploy') {
            steps {
                echo 'Running deployment script..'
                sh 'export INSIDE_DOCKER=true'
                sh 'command -v docker'
                sh 'command -v docker compose'
                sh './scripts/deploy.sh'
            }
        }
    }
}
