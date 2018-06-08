pipeline {
  agent {
    node {
      label 'bl-jks-25-new'
    }

  }
  stages {
    stage('Clone repository') {
      steps {
        checkout scm      
      }
    }
    
    stage('Build image') {
      steps {
        script {
          def dockerfile = 'Dockerfile'
          def tag = 'nexus.devuk.mimecast.lan:18079/clickhouse:1.2'
          def app = docker.build("$tag", "-f $dockerfile ./")
          //sh "docker push ${tag}"
        }
      }
    }

    stage('Create rpms') {
      agent {
        docker { 
          image '$tag'
          args '-v ${PWD}:/root -w /root'
          reuseNode true
        } 
      }
      
      steps {
       sh 'whoami && pwd && ls -l'

      }
    }
  }
}


