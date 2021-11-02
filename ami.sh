#It create ami by tag and after that delete old after campare with date
#!/bin/bash
export DATE_CURRENT=`date +%Y-%m-%d`
export TIME_CURRENT=`date +%Y%m%d%H%M%S`
export PURGE_AFTER_DAYS=30
export PURGE_AFTER=`date -d +${PURGE_AFTER_DAYS}days -u +%Y-%m-%d`
export BACKUP_TAG='backup'

# 1-1 Get the list of instances that you want to get backup
INSTANCES=`aws ec2 describe-tags --filters "Name=resource-type,Values=instance" "Name=key,Values=${BACKUP_TAG}" | awk '{print $3}'`

for INSTANCE in ${INSTANCES}; do

  BACKUP=`aws ec2 describe-tags --filters "Name=resource-type,Values=instance" "Name=resource-id,Values=${INSTANCE}" "Name=key,Values=${BACKUP_TAG}" | awk '{print $5}'`

  # 1-2 Check if the instance is marked as backup or not
  if [ "${BACKUP}" == "true" ]; then

    # 1-3 Create a backup
    AMI_ID=`aws ec2 create-image --instance-id ${INSTANCE} --name "${INSTANCE}_${TIME_CURRENT}" --no-reboot`

    # 1-4 Create a tag for search for later use
    aws ec2 create-tags --resources ${AMI_ID} --tags Key=PurgeAllow,Value=true Key=PurgeAfter,Value=$PURGE_AFTER
  fi
done

# 2-1 Search backups by tag
AMI_PURGE_ALLOWED=`aws ec2 describe-tags --filters "Name=resource-type,Values=image" "Name=key,Values=PurgeAllow" | awk '{print $3}'`

for AMI_ID in ${AMI_PURGE_ALLOWED}; do
  PURGE_AFTER_DATE=`aws ec2 describe-tags --filters "Name=resource-type,Values=image" "Name=resource-id,Values=${AMI_ID}" "Name=key,Values=PurgeAfter"  | awk '{print $5}'`

  if [ -n ${PURGE_AFTER_DATE} ]; then
    DATE_CURRENT_EPOCH=`date -d ${DATE_CURRENT} +%s`
    PURGE_AFTER_DATE_EPOCH=`date -d ${PURGE_AFTER_DATE} +%s`

    if [[ ${PURGE_AFTER_DATE_EPOCH} < ${DATE_CURRENT_EPOCH} ]]; then
      # 2-2 Delete backup if it is marked as backup
      aws ec2 deregister-image --image-id ${AMI_ID}

      SNAPSHOT_ID=`aws ec2 describe-images --image-ids ${AMI_ID} | grep EBS | awk '{print $4}'`
      aws ec2 delete-snapshot --snapshot-id ${SNAPSHOT_ID}
    fi
  fi
done
