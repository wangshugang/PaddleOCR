#!/bin/bash
source test_tipc/common_func.sh

FILENAME=$1
# MODE be one of [''whole_infer']
MODE=$2

IFS=$'\n'
# parser klquant_infer params

dataline=$(awk 'NR==1, NR==17{print}'  $FILENAME)
lines=(${dataline})
model_name=$(func_parser_value "${lines[1]}")
python=$(func_parser_value "${lines[2]}")
export_weight=$(func_parser_key "${lines[3]}")
save_infer_key=$(func_parser_key "${lines[4]}")
# parser inference model 
infer_model_dir_list=$(func_parser_value "${lines[5]}")
infer_export_list=$(func_parser_value "${lines[6]}")
infer_is_quant=$(func_parser_value "${lines[7]}")
# parser inference 
inference_py=$(func_parser_value "${lines[8]}")
use_gpu_key=$(func_parser_key "${lines[9]}")
use_gpu_list=$(func_parser_value "${lines[9]}")
use_mkldnn_key=$(func_parser_key "${lines[10]}")
use_mkldnn_list=$(func_parser_value "${lines[10]}")
cpu_threads_key=$(func_parser_key "${lines[11]}")
cpu_threads_list=$(func_parser_value "${lines[11]}")
batch_size_key=$(func_parser_key "${lines[12]}")
batch_size_list=$(func_parser_value "${lines[12]}")
use_trt_key=$(func_parser_key "${lines[13]}")
use_trt_list=$(func_parser_value "${lines[13]}")
precision_key=$(func_parser_key "${lines[14]}")
precision_list=$(func_parser_value "${lines[14]}")
infer_model_key=$(func_parser_key "${lines[15]}")
image_dir_key=$(func_parser_key "${lines[16]}")
infer_img_dir=$(func_parser_value "${lines[16]}")
save_log_key=$(func_parser_key "${lines[17]}")
save_log_value=$(func_parser_value "${lines[17]}")
benchmark_key=$(func_parser_key "${lines[18]}")
benchmark_value=$(func_parser_value "${lines[18]}")
infer_key1=$(func_parser_key "${lines[19]}")
infer_value1=$(func_parser_value "${lines[19]}")


LOG_PATH="./test_tipc/output/${model_name}/${MODE}"
mkdir -p ${LOG_PATH}
status_log="${LOG_PATH}/results_python.log"


function func_inference(){
    IFS='|'
    _python=$1
    _script=$2
    _model_dir=$3
    _log_path=$4
    _img_dir=$5
    _flag_quant=$6
    # inference 
    for use_gpu in ${use_gpu_list[*]}; do
        if [ ${use_gpu} = "False" ] || [ ${use_gpu} = "cpu" ]; then
            for use_mkldnn in ${use_mkldnn_list[*]}; do
                for threads in ${cpu_threads_list[*]}; do
                    for batch_size in ${batch_size_list[*]}; do
                        for precision in ${precision_list[*]}; do
                            if [ ${use_mkldnn} = "False" ] && [ ${precision} = "fp16" ]; then
                                continue
                            fi # skip when enable fp16 but disable mkldnn
                            if [ ${_flag_quant} = "True" ] && [ ${precision} != "int8" ]; then
                                continue
                            fi # skip when quant model inference but precision is not int8
                            set_precision=$(func_set_params "${precision_key}" "${precision}")
                            
                            _save_log_path="${_log_path}/python_infer_cpu_usemkldnn_${use_mkldnn}_threads_${threads}_precision_${precision}_batchsize_${batch_size}.log"
                            set_infer_data=$(func_set_params "${image_dir_key}" "${_img_dir}")
                            set_benchmark=$(func_set_params "${benchmark_key}" "${benchmark_value}")
                            set_batchsize=$(func_set_params "${batch_size_key}" "${batch_size}")
                            set_mkldnn=$(func_set_params "${use_mkldnn_key}" "${use_mkldnn}")
                            set_cpu_threads=$(func_set_params "${cpu_threads_key}" "${threads}")
                            set_model_dir=$(func_set_params "${infer_model_key}" "${_model_dir}")
                            set_infer_params0=$(func_set_params "${save_log_key}" "${save_log_value}")
                            set_infer_params1=$(func_set_params "${infer_key1}" "${infer_value1}")
                            command="${_python} ${_script} ${use_gpu_key}=${use_gpu} ${set_mkldnn} ${set_cpu_threads} ${set_model_dir} ${set_batchsize} ${set_infer_params0} ${set_infer_data} ${set_benchmark} ${set_precision} ${set_infer_params1} > ${_save_log_path} 2>&1 "
                            eval $command
                            last_status=${PIPESTATUS[0]}
                            eval "cat ${_save_log_path}"
                            status_check $last_status "${command}" "${status_log}" "${model_name}"
                        done
                    done
                done
            done
        elif [ ${use_gpu} = "True" ] || [ ${use_gpu} = "gpu" ]; then
            for use_trt in ${use_trt_list[*]}; do
                for precision in ${precision_list[*]}; do
                    if [ ${_flag_quant} = "True" ] && [ ${precision} != "int8" ]; then
                        continue
                    fi # skip when quant model inference but precision is not int8
                    for batch_size in ${batch_size_list[*]}; do
                        _save_log_path="${_log_path}/python_infer_gpu_usetrt_${use_trt}_precision_${precision}_batchsize_${batch_size}.log"
                        set_infer_data=$(func_set_params "${image_dir_key}" "${_img_dir}")
                        set_benchmark=$(func_set_params "${benchmark_key}" "${benchmark_value}")
                        set_batchsize=$(func_set_params "${batch_size_key}" "${batch_size}")
                        set_tensorrt=$(func_set_params "${use_trt_key}" "${use_trt}")
                        set_precision=$(func_set_params "${precision_key}" "${precision}")
                        set_model_dir=$(func_set_params "${infer_model_key}" "${_model_dir}")
                        set_infer_params0=$(func_set_params "${save_log_key}" "${save_log_value}")
                        set_infer_params1=$(func_set_params "${infer_key1}" "${infer_value1}")
                        command="${_python} ${_script} ${use_gpu_key}=${use_gpu} ${set_tensorrt} ${set_precision} ${set_model_dir} ${set_batchsize} ${set_infer_data} ${set_benchmark} ${set_infer_params1} ${set_infer_params0} > ${_save_log_path} 2>&1 "
                        eval $command
                        last_status=${PIPESTATUS[0]}
                        eval "cat ${_save_log_path}"
                        status_check $last_status "${command}" "${status_log}" "${model_name}"
                        
                    done
                done
            done
        else
            echo "Does not support hardware other than CPU and GPU Currently!"
        fi
    done
}

if [ ${MODE} = "whole_infer" ]; then
    GPUID=$3
    if [ ${#GPUID} -le 0 ];then
        env=" "
    else
        env="export CUDA_VISIBLE_DEVICES=${GPUID}"
    fi
    # set CUDA_VISIBLE_DEVICES
    eval $env
    export Count=0
    IFS="|"
    infer_run_exports=(${infer_export_list})
    infer_quant_flag=(${infer_is_quant})
    for infer_model in ${infer_model_dir_list[*]}; do
        # run export
        if [ ${infer_run_exports[Count]} != "null" ];then
            save_infer_dir="${infer_model}_klquant"
            set_export_weight=$(func_set_params "${export_weight}" "${infer_model}")
            set_save_infer_key=$(func_set_params "${save_infer_key}" "${save_infer_dir}")
            export_log_path="${LOG_PATH}/${MODE}_export_${Count}.log"
            export_cmd="${python} ${infer_run_exports[Count]} ${set_export_weight} ${set_save_infer_key} > ${export_log_path} 2>&1 "
            echo ${infer_run_exports[Count]} 
            echo $export_cmd
            eval $export_cmd
            status_export=$?
            status_check $status_export "${export_cmd}" "${status_log}" "${model_name}"
        else
            save_infer_dir=${infer_model}
        fi
        #run inference
        is_quant="True"
        func_inference "${python}" "${inference_py}" "${save_infer_dir}" "${LOG_PATH}" "${infer_img_dir}" ${is_quant}
        Count=$(($Count + 1))
    done
fi

