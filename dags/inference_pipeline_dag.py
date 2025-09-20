import os, sys
from airflow import DAG
from airflow.utils import timezone
from datetime import datetime, timedelta
from airflow.operators.python import PythonOperator
import pytz

project_root = '/mnt/c/Users/hewaj/Desktop/Zuu Crew/Customer Churn Prediction - AirFlow' # this path is since dag is in WSL2
sys.path.insert(0, project_root)

from utils.airflow_tasks import validate_trained_model, run_inference_pipeline

"""

============== DAG ============================

Validate Trained Model -> Run Train Pipeline Task

"""

# INFERENCE PIPELINE DAG - Every 10 minutes (instead of every minute)
ist = pytz.timezone('Asia/Colombo')
default_arguments_inference = {
    'owner': 'zuu-crew',
    'depends_on_past': False,
    'start_date': ist.localize(datetime(2025, 9, 20, 11, 0)),  # Start from 11:00 AM today
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=1),
}

with DAG(
    dag_id='inference_pipeline_dag',
    schedule_interval='*/1 * * * *',  # Every 10 minutes instead of every minute
    catchup=False,
    max_active_runs=1,
    default_args=default_arguments_inference,
    description='Inference Pipeline - Every 10 Minutes Scheduled',
    tags=['pyspark', 'mllib', 'mlflow', 'batch-processing']
    ) as dag:
    
    # Step 1
    validate_trained_model_task = PythonOperator(
                                            task_id='validate_trained_model',
                                            python_callable=validate_trained_model,
                                            execution_timeout=timedelta(minutes=2)
                                            )

    # Step 2
    run_inference_pipeline_task = PythonOperator(
                                            task_id='run_training_pipeline',
                                            python_callable=run_inference_pipeline,
                                            execution_timeout=timedelta(minutes=2)
                                            )

    validate_trained_model_task >> run_inference_pipeline_task