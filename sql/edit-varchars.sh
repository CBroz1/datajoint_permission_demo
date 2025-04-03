#!/bin/bash

for file in ./_Pop*sql; do \
    echo $file
    sed -i 's/ DEFAULT CHARSET=[^ ]\w*//g' "$file"
    sed -i 's/ DEFAULT COLLATE [^ ]\w*//g' "$file"
    sed -i 's/ `nwb_file_name` varchar(255)/ `nwb_file_name` varchar(64)/g' "$file"
    sed -i 's/ `analysis_file_name` varchar(255)/ `analysis_file_name` varchar(64)/g' "$file"
    sed -i 's/ `interval_list_name` varchar(200)/ `interval_list_name` varchar(170)/g' "$file"
    sed -i 's/ `position_info_param_name` varchar(80)/ `position_info_param_name` varchar(32)/g' "$file"
    sed -i 's/ `mark_param_name` varchar(80)/ `mark_param_name` varchar(32)/g' "$file"
    sed -i 's/ `artifact_removed_interval_list_name` varchar(200)/ `artifact_removed_interval_list_name` varchar(128)/g' "$file"
    sed -i 's/ `metric_params_name` varchar(200)/ `metric_params_name` varchar(64)/g' "$file"
    sed -i 's/ `auto_curation_params_name` varchar(200)/ `auto_curation_params_name` varchar(36)/g' "$file"
    sed -i 's/ `sort_interval_name` varchar(200)/ `sort_interval_name` varchar(64)/g' "$file"
    sed -i 's/ `preproc_params_name` varchar(200)/ `preproc_params_name` varchar(32)/g' "$file"
    sed -i 's/ `sorter` varchar(200)/ `sorter` varchar(32)/g' "$file"
    sed -i 's/ `sorter_params_name` varchar(200)/ `sorter_params_name` varchar(64)/g' "$file"
done

