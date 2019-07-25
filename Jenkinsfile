#!/usr/bin/env groovy

node {
    checkout scm
    def buildlib = load("pipeline-scripts/buildlib.groovy")
    def commonlib = buildlib.commonlib

    // Expose properties for a parameterized build
    properties(
        [
            buildDiscarder(
                logRotator(
                    artifactDaysToKeepStr: '',
                    artifactNumToKeepStr: '',
                    daysToKeepStr: '',
                    numToKeepStr: '')),
            [
                $class: 'ParametersDefinitionProperty',
                parameterDefinitions: [
                    [
                        name: 'STREAM',
                        description: 'Build stream to sync client from',
                        $class: 'hudson.model.StringParameterDefinition',
                        defaultValue: "4.1.0-0.nightly"
                    ],
                    [
                        name: 'PATH',
                        description: 'artifacts path of https://mirror.openshift.com',
                        $class: 'hudson.model.StringParameterDefinition',
                        defaultValue: "/srv/pub/openshift-v4/clients/ocp/"
                    ],
                    [
                        name: 'MAIL_LIST_FAILURE',
                        description: 'Failure Mailing List',
                        $class: 'hudson.model.StringParameterDefinition',
                        defaultValue: [
                            'aos-team-art@redhat.com'
                        ].join(',')
                    ],
                    commonlib.mockParam(),
                ]
            ],
            disableConcurrentBuilds()
        ]
    )

    commonlib.checkMock()



    try {
        sshagent(['aos-cd-test']) {
            stage("sync ocp clients") {
		// must be able to access remote registry to extract image contents
		buildlib.registry_quay_dev_login()
                sh "./publish-clients-from-payload.sh ${env.WORKSPACE} ${STREAM} ${PATH}"
            }
        }
    } catch (err) {
        commonlib.email(
            to: "${params.MAIL_LIST_FAILURE}",
            from: "aos-cicd@redhat.com",
            subject: "Error syncing ocp client from payload",
            body: "Encountered an error while syncing ocp client from payload: ${err}");
        currentBuild.description = "Error while syncing ocp client from payload:\n${err}"
        currentBuild.result = "FAILURE"
        throw err
    }
    buildlib.cleanWorkdir("${env.WORKSPACE}")
}
