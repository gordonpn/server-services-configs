pipeline {
    agent any

    stages {
        stage('Deploy') {
            steps {
                echo 'Running deployment script..'
                sh 'pwd'
                sh 'hostname'
                sh 'whoami'
                sh './scripts/deploy.sh'
            }
        }
    }
}
