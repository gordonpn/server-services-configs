pipeline {
    agent any

    stages {
        stage('Deploy') {
            steps {
                echo 'Running deployment script..'
                sh 'pwd'
                sh './scripts/deploy.sh'
            }
        }
    }
}
