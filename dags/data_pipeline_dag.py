import os, sys
from airflow import DAG
from airflow.utils import timezone
from datetime import datetime, timedelta
from airflow.operators.python import PythonOperator
import pytz

project_root = '/mnt/c/Users/hewaj/Desktop/Zuu Crew/Customer Churn Prediction - AirFlow' # this path is since dag is in WSL2
sys.path.insert(0, project_root)

from utils.airflow_tasks import validate_input_data, run_data_pipeline

"""

============== DAG ============================

Validate Input Data -> Run Data Pipeline Task

"""

# DATA PIPELINE DAG - Every 15 minutes (more reasonable than 5)
ist = pytz.timezone('Asia/Colombo')
default_arguments_data = {
    'owner': 'zuu-crew',
    'depends_on_past': False,
    'start_date': ist.localize(datetime(2025, 9, 20, 11, 0)),  
    'email_on_failure': False,  # Fixed typo: 'failuer' -> 'failure'
    'email_on_retry': False,
    'retries': 1,  # At least 1 retry is recommended
    'retry_delay': timedelta(minutes=2),
}

with DAG(
    dag_id='data_pipeline_dag',
    schedule_interval='*/5 * * * *',  # Every 15 minutes instead of 5
    catchup=False,
    max_active_runs=1,
    default_args=default_arguments_data,
    description='Data Pipeline - Every 15 Minutes Scheduled',
    tags=['pyspark', 'mllib', 'mlflow', 'batch-processing']
    ) as dag:
    
    # Step 1
    validate_input_data_task = PythonOperator(
                                            task_id='validate_input_data',
                                            python_callable=validate_input_data,
                                            execution_timeout=timedelta(minutes=2)
                                            )

    # Step 2
    run_data_pipeline_task = PythonOperator(
                                            task_id='run_data_pipeline',
                                            python_callable=run_data_pipeline,
                                            execution_timeout=timedelta(minutes=15)
                                            )

    validate_input_data_task >> run_data_pipeline_task