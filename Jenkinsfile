pipeline {
    agent any

    stages {
        stage('Deploy') {
            steps {
                echo 'Running deployment script..'
                sh 'pwd'
                sh 'ls /home/gordonpn/workspace'
                sh './scripts/deploy.sh'
            }
        }
    }
}
