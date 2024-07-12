# ci-migration

Script approaches of migration steps for Jenkins OSS LTS to CI Controller (k8s) 

Links I followed to develop the scripts:

* https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/client-and-managed-controllers/migrating-jenkins-instances
* https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/client-and-managed-controllers/migrating-jenkins-to-a-new-machine
* https://docs.cloudbees.com/docs/cloudbees-ci-migration/latest/
* https://docs.cloudbees.com/docs/cloudbees-ci-migration/latest/cloudbees-jenkins-platform-to-cloudbees-ci/
* https://docs.cloudbees.com/docs/cloudbees-ci-migration/latest/jenkins-to-ci-trad-migration/
* https://www.youtube.com/watch?v=urmNi61PDbc
* https://docs.cloudbees.com/docs/cloudbees-ci-api/latest/bundle-management-api
* https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/create-bundle

# Steps: Copy approach 

* Create a backup from the legacy Controller (Jenkins OSS LTS usually)
* Create a target Controller (Kubernetes)
** Optional: Assign an existing [casc bundle](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/create-bundle) with plugins 
* Copy the backup file to the target Controller
* Extract the backup file and overwrite JENKINS_HOME on the target Controller
* Restart the Controller
* Migrate Credentials
* Run Acceptance test

See scripted example: [lts2modern.sh](lts2modern.sh)

# Steps: Casc approach

* Export a list of installed plugins from the legacy Controller 
* convert the list to `plugins.yaml`
* Install the [JCasC](https://github.com/jenkinsci/configuration-as-code-plugin) Plugin on the legacy Controller
* Export `jenkins.yaml` from legacy Controller
* Bake a [casc bundle](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/create-bundle), including the `plugins,yaml` and `jenkins yaml`
* review the `jenkins.yaml` , optimize/clean it
* Create a new controller from casc bundle
See example: TODO


