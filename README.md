# ci-migration

Scripting approaches of steps described here for the Jenkins CI Controller migrations

links i followed:

* https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/client-and-managed-controllers/migrating-jenkins-instances
* https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/client-and-managed-controllers/migrating-jenkins-to-a-new-machine
* https://docs.cloudbees.com/docs/cloudbees-ci-migration/latest/
* https://docs.cloudbees.com/docs/cloudbees-ci-migration/latest/cloudbees-jenkins-platform-to-cloudbees-ci/
* https://docs.cloudbees.com/docs/cloudbees-ci-migration/latest/jenkins-to-ci-trad-migration/
* https://www.youtube.com/watch?v=urmNi61PDbc

# Steps: Copy approach 

* Create a backup from the legacy Controller (Jenkins OSS LTS usually)
* Create a target Controller (Kubernetes)
* Use existing casc bundle with plugins
* Copy the backup to the target Controller
* Extract the backup and overwrite JENKINS_HOME on the target Controller
* Restart the Controller
* Migrate Credentials
* Run Acceptance test

See scripted example: [lts2modern.sh](lts2modern.sh)

# Steps: Casc approach

* Export a list of installed plugins from teh legacy Controller 
* convert the list to plugins.yaml
* Install JCasC on the legacy Controller
* Export jenkins.yaml from legacy Controller
* Bake a casc bundle with the plugins and jenkins yaml
* review the jenkins.yaml, optimize/clean it
* Create a new controller from casc bundle
See example: TODO


