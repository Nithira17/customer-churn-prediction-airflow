import os, sys
from airflow import DAG
from airflow.utils import timezone
from datetime import datetime, timedelta
from airflow.operators.python import PythonOperator
import pytz

project_root = '/mnt/c/Users/hewaj/Desktop/Zuu Crew/Customer Churn Prediction - AirFlow' # this path is since dag is in WSL2
sys.path.insert(0, project_root)

from utils.airflow_tasks import validate_processed_data, run_training_pipeline

"""

============== DAG ============================

Validate Processed Data -> Run Train Pipeline Task

"""

# TRAINING PIPELINE DAG - Daily at 1:00 AM IST
ist = pytz.timezone('Asia/Colombo')
default_arguments_train = {
    'owner': 'zuu-crew',
    'depends_on_past': False,
    'start_date': ist.localize(datetime(2025, 9, 20, 11, 0)),  # Start from 11:00 AM today
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,  # More retries for training jobs
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    dag_id='train_pipeline_dag',
    schedule_interval='30 19 * * *', # 19:30 UTC = 01:00 Colombo time
    catchup=False,
    max_active_runs=1,
    default_args=default_arguments_train,
    description='Train Pipeline - Daily at 1:00 AM IST (19:30 UTC)',
    tags=['pyspark', 'mllib', 'mlflow', 'batch-processing'] # this is to use our time zone for schedule interval
    ) as dag:
    
    # Step 1
    validate_processed_data_task = PythonOperator(
                                            task_id='validate_processed_data',
                                            python_callable=validate_processed_data,
                                            execution_timeout=timedelta(minutes=2)
                                            )

    # Step 2
    run_training_pipeline_task = PythonOperator(
                                            task_id='run_training_pipeline',
                                            python_callable=run_training_pipeline,
                                            execution_timeout=timedelta(minutes=30)
                                            )

    validate_processed_data_task >> run_training_pipeline_task