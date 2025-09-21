pipeline {
  agent any
  environment {
    APP_NAME = 'devops-build'
    DOCKERHUB_USER = credentials('dockerhub-username')
    DOCKERHUB_PASS = credentials('dockerhub-password')
  }
  triggers { githubPush() }
  options { timestamps() }
  stages {
    stage('Checkout') {
      steps { checkout scm }
    }
    stage('Set Channel & Tag') {
      steps {
        script {
          BRANCH = env.BRANCH_NAME
          CHANNEL = (BRANCH == 'master' || BRANCH == 'main') ? 'prod' : 'dev'
          IMAGE_TAG = "${env.BUILD_NUMBER}"
          env.CHANNEL = CHANNEL
          env.IMAGE_TAG = IMAGE_TAG
        }
      }
    }
    stage('Build & Push') {
      steps {
        sh '''
          export DOCKERHUB_USER=${DOCKERHUB_USER}
          export DOCKERHUB_PASS=${DOCKERHUB_PASS}
          export APP_NAME=${APP_NAME}
          ./build.sh "${CHANNEL}" "${IMAGE_TAG}"
        '''
      }
    }
    stage('Deploy (EC2)') {
      when { anyOf { branch 'dev'; branch 'master'; branch 'main' } }
      environment {
        DEPLOY_HOST = credentials('ec2-host-ip')
      }
      steps {
        sh '''
          export DOCKERHUB_USER=${DOCKERHUB_USER}
          export APP_NAME=${APP_NAME}
          ./deploy.sh "${DEPLOY_HOST}" "${CHANNEL}" "${IMAGE_TAG}"
        '''
      }
    }
  }
}
