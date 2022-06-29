pipeline {
    agent any

    stages {
        stage('Deploy') {
            steps {
                echo 'Running deployment script..'
                sh 'pwd'
                sh 'hostnamectl'
                sh 'whoami'
                sh './scripts/deploy.sh'
            }
        }
    }
}
