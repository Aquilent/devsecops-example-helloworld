#!groovy

import groovy.json.JsonSlurper

pipeline {
	agent none
    parameters {
        string(name: 'IMAGE_NAME', defaultValue: 'hello-world', description: '-')
        string(name: 'REGISTRY_URL', description: '-')
        string(name: 'REGISTRY_CREDENTIALS_ID', description: '-')
    }
    options {
        timeout(time: 1, unit: 'DAYS')
        disableConcurrentBuilds()
    }
	stages {
		stage("Init") {
			agent any
			steps { initialize() }
		}
		stage("Package") {
			agent { docker "maven:3.5.0-jdk-8-alpine"}
			steps {
                sh "(cd ./webapp; mvn clean install)"
                sh "ls ./webapp/target"
             }
		}
        stage("Build and Register Image") {
            agent any
            steps {
                buildAndRegisterDockerImage(params.IMAGE_NAME, params.REGISTRY_URL,
                    params.REGISTRY_CREDENTIALS_ID) 
            }
        }
		// stage("Proceed to test?") {
		// 	agent none
		// 	when { branch 'master' }
		// 	steps { proceedTo('test') }
		// }
		// stage("Deploy to test") {
		// 	agent { docker "garland/aws-cli-docker"}
        //     when { expression { (env.BRANCH_NAME == 'master') && (env.PROCEED_TO_TEST == 'yes' ) } }
		// 	steps { deployPackages('test') }
		// }
	}
}


// ================================================================================================
// Initialization steps
// ================================================================================================

def initialize() {
    setEnvironment()
	env.APP_NAMES = "HelloWorld"
	env.TARGET_DIR = "${env.WORKSPACE}/target"
	echo "TARGET_DIR=${env.TARGET_DIR}"
    showEnvironmentVariables()
	sh "mkdir -p ${env.TARGET_DIR}"
}

def setEnvironment() {
    def branchName = env.BRANCH_NAME.toLowerCase()
    def environment = 'dev'
    echo "branchName = ${branchName}"
    if (branchName == "") {
        showEnvironmentVariables()
        throw "BRANCH_NAME is not an environment variable or is empty"
    } else if (branchName != "master") {
		//echo "split"
        if (branchName.contains("/")) {
            // ignore branch type
            branchName = branchName.split("/")[1]
        }
        //echo "remove '-' characters'"
        branchName = branchName.replace("-", "")
        //echo "remove JIRA project name"
        if (env.JIRA_PROJECT_NAME) {
            branchName = branchName.replace(env.JIRA_PROJECT_NAME, "")
        }
        // echo "limit length"
        branchName = branchName.take(env.MAX_ENVIRONMENTNAME_LENGTH as Integer)
        environment += branchName
    }
    echo "Using environment: ${environment}"
    env.ENVIRONMENT = environment
}

def showEnvironmentVariables() {
    sh 'env | sort > env.txt'
    sh 'cat env.txt'
}

// ================================================================================================
// Build steps
// ================================================================================================

def buildAndRegisterDockerImage(imageBaseName, url, credentialsID) {
    def imageName = "${imageBaseName}:${env.BUILD_ID}"
	docker.withRegistry(url, credentialsID) {
        withCredentials([[
            $class: 'UsernamePasswordMultiBinding', 
            credentialsId: credentialsID,
            usernameVariable: 'USERNAME',
            passwordVariable: 'PASSWORD']]) 
        {
            sh "docker login -u $USERNAME -p $PASSWORD ${url}"
        }
        docker.build(imageName).push()
        sh "docker logout"
    }
}


// ================================================================================================
// Utility steps
// ================================================================================================

def aws_cli(command, region = null) {
	if (!region) {
		region = env.AWS_REGION
	}
	sh "aws ${command} --region ${region}"
}

def proceedTo(environment) {
    def description = "Choose 'yes' if you want to deploy to this build to " + 
        "the ${environment} environment"
    timeout(time: 4, unit: 'HOURS') {
        env.PROCEED_TO_TEST = input message: "Do you want to deploy the changes to ${environment}?",
            parameters: [choice(name: "Deploy to ${environment}", choices: "no\nyes",
                description: description)]
    }
}

