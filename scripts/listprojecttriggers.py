import json
import sys


cloud_deployment_branch='develop'

if len(sys.argv) > 2:
    project_id = sys.argv[2]
    projectsfile = open(sys.argv[1])
    projects = json.load(projectsfile)
    for pr in projects['projects']:
        if pr['projectId'] == project_id and 'triggers' in pr and len(pr['triggers']) > 0:
            for tr in pr['triggers']:
                if not 'projectId' in tr['triggerTemplate']:
                    tr['triggerTemplate']['projectId'] = pr['projectId']
                tr['description'] = 'Push to {} {} branch'.format(
                    tr['triggerTemplate']['repoName'],
                    tr['triggerTemplate']['branchName'])
                if 'runTrigger' in tr:
                    tr['build'] = {
			'steps': [
			    {
				'name': 'gcr.io/cloud-builders/git',
				'args': [
				    'clone',
				    '--branch={}'.format(cloud_deployment_branch),
				    'https://github.com/vwt-digital/cloud-deployment.git'
				]
			    },
			    {
				'name': 'gcr.io/cloud-builders/gcloud',
				'entrypoint': 'bash',
				'args': [
				    '-c',
				    './runcloudbuildtrigger.sh ${{PROJECT_ID}} {} {}'.format(
					tr['runTrigger']['repoName'],
					tr['runTrigger']['branchName'])
				],
				'dir': 'cloud-deployment/scripts'
			    }
			]
		    }
                    del tr['runTrigger']
                print(json.dumps(tr))