import yaml
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.compute import ClusterSpec
from databricks.sdk.service.jobs import (
    CronSchedule,
    NotebookTask,
    Source,
    Task,
)

from dougslldataplatform.config import config


def ingest():

    config_file = config()

    job_name = config_file['resources']['job_ingest']['name']
    job_schedule = config_file['resources']['job_ingest']['schedule']
    job_type = config_file['resources']['job_ingest']['type']
    job_cluster_size = config_file['resources']['job_ingest'][
        'job_cluster_size'
    ]

    mt_project = config_file['resources']['metadata']['project']
    mt_domain = config_file['resources']['metadata']['domain']

    description = 'Template job to ingest data master1'
    task_key = 'ingest'
    notebook_path = '/Users/douglas.sleal@outlook.com/helloworld'

    host = 'https://adb-686279278669385.5.azuredatabricks.net'
    token = 'dapi15c1df153dd52a64d612be3177b7fbe2'
    w = WorkspaceClient(host=host, token=token)

    # print("Attempting to create the job. Please wait...\n")
    return 'job criado com sucesso'

    # j = w.jobs.create(
    # name = job_name,
    # schedule = CronSchedule(
    #     quartz_cron_expression = cron,
    #     timezone_id = 'America/Sao_Paulo',
    # ),
    # tasks = [
    #     Task(
    #     description = description,
    #     notebook_task = NotebookTask(
    #         base_parameters = dict(""),
    #         notebook_path = notebook_path,
    #         source = Source("WORKSPACE"),
    #     ),
    #     task_key = task_key,

    #     new_cluster = ClusterSpec(
    #         spark_version = '14.3.x-scala2.12',
    #         num_workers=0,
    #         node_type_id='Standard_F4',
    #         driver_node_type_id='Standard_F4',
    #         spark_conf={
    #             "spark.master":"local[*, 4]",
    #             "spark.databricks.cluster.profile":"singleNode"},
    #     ),
    #     )
    # ]
    # )

    # print(f"View the job at {w.config.host}/#job/{j.job_id}\n")
