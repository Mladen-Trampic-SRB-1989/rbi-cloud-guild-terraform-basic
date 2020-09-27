locals {
  accounts = distinct(concat([data.aws_caller_identity.current.account_id], var.accounts))
  bucket_name = format("%s-%s",var.bucket_name,random_id.salt.dec)
  dynamo_name = format("%s-%s",var.dynamo_name,random_id.salt.dec)
}

resource "random_id" "salt" {
	  byte_length = 8
}

resource "aws_iam_role" "replication" {
  name = "terraform-iam-role-replication"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {   
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      }
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "replication" {
  name = "terraform-iam-role-policy-replication"

  policy = <<POLICY
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Action":[
            "s3:ListBucket",
            "s3:GetReplicationConfiguration",
            "s3:GetObjectVersionForReplication",
            "s3:GetObjectVersionAcl"
         ],
         "Effect":"Allow",
         "Resource":[
            "arn:aws:s3:::${local.bucket_name}",
            "arn:aws:s3:::${local.bucket_name}/*"
         ]
      },
      {
         "Action":[
            "s3:ReplicateObject",
            "s3:ReplicateDelete",
            "s3:ReplicateTags",
            "s3:GetObjectVersionTagging"
         ],
         "Effect":"Allow",
         "Condition":{
            "StringLikeIfExists":{
               "s3:x-amz-server-side-encryption":[
                  "aws:kms",
                  "AES256"
               ],
               "s3:x-amz-server-side-encryption-aws-kms-key-id":[
                  "${aws_kms_key.terraform-replica.arn}"
               ]
            }
         },
         "Resource":"arn:aws:s3:::${local.bucket_name}-replica/*"
      },
      {
         "Action":[
            "kms:Decrypt"
         ],
         "Effect":"Allow",
         "Condition":{
            "StringLike":{
               "kms:ViaService":"s3.${var.region}.amazonaws.com",
               "kms:EncryptionContext:aws:s3:arn":[
                  "arn:aws:s3:::${local.bucket_name}/*"
               ]
            }
         },
         "Resource":[
            "${aws_kms_key.terraform.arn}"
         ]
      },
      {
         "Action":[
            "kms:Encrypt"
         ],
         "Effect":"Allow",
         "Condition":{
            "StringLike":{
               "kms:ViaService":"s3.${var.replica_region}.amazonaws.com",
               "kms:EncryptionContext:aws:s3:arn":[
                  "arn:aws:s3:::${local.bucket_name}-replica/*"
               ]
            }
         },
         "Resource":[
            "${aws_kms_key.terraform-replica.arn}"
         ]
      }
   ]
}
POLICY
}

resource "aws_iam_policy_attachment" "replication" {
  name       = "terraform-iam-role-attachment-replication"
  roles      = [aws_iam_role.replication.name]
  policy_arn = aws_iam_policy.replication.arn
}


# For encryption
resource "aws_kms_key" "terraform" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "bucket" {
  force_destroy = true
  bucket        = local.bucket_name
  acl           = "private"

  versioning {
    enabled = true
  }

  replication_configuration {
    role = aws_iam_role.replication.arn

    rules {
      id     = "All_files"
      status = "Enabled"

      source_selection_criteria {
        sse_kms_encrypted_objects {
          enabled = true
        }
      }

      destination {
        bucket             = aws_s3_bucket.destination.arn
        storage_class      = "STANDARD"
        replica_kms_key_id = aws_kms_key.terraform-replica.arn
      }
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.terraform.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  policy = <<POLICY
{
     "Version": "2012-10-17",
     "Id": "PutObjPolicy",
     "Statement": [
           {
                "Sid": "DenyIncorrectEncryptionHeader",
                "Effect": "Deny",
                "Principal": "*",
                "Action": "s3:PutObject",
                "Resource": "arn:aws:s3:::${local.bucket_name}/*",
                "Condition": {
                        "StringNotEquals": {
                               "s3:x-amz-server-side-encryption": "aws:kms"
                         }
                }
           },
           {
                "Sid": "DenyUnEncryptedObjectUploads",
                "Effect": "Deny",
                "Principal": "*",
                "Action": "s3:PutObject",
                "Resource": "arn:aws:s3:::${local.bucket_name}/*",
                "Condition": {
                        "Null": {
                               "s3:x-amz-server-side-encryption": "true"
                        }
               }
           }
     ]
}
POLICY
}

resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}



# For locking
resource "aws_dynamodb_table" "dynamodb-terraform_state-lock" {
  name           = local.dynamo_name
  hash_key       = "LockID"
  read_capacity  = 20
  write_capacity = 20

  attribute {
    name = "LockID"
    type = "S"
  }
}

#Replica region
resource "aws_kms_key" "terraform-replica" {
  provider                = aws.replica
  description             = "This key is used to encrypt bucket objects on the replicated bucket"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "destination" {
  force_destroy = true
  provider      = aws.replica
  bucket        = "${local.bucket_name}-replica"

  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.terraform-replica.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
  policy = <<POLICY
{
     "Version": "2012-10-17",
     "Id": "PutObjPolicy",
     "Statement": [
           {
                "Sid": "DenyIncorrectEncryptionHeader",
                "Effect": "Deny",
                "Principal": "*",
                "Action": "s3:PutObject",
                "Resource": "arn:aws:s3:::${local.bucket_name}-replica/*",
                "Condition": {
                        "StringNotEquals": {
                               "s3:x-amz-server-side-encryption": "aws:kms"
                         }
                }
           },
           {
                "Sid": "DenyUnEncryptedObjectUploads",
                "Effect": "Deny",
                "Principal": "*",
                "Action": "s3:PutObject",
                "Resource": "arn:aws:s3:::${local.bucket_name}-replica/*",
                "Condition": {
                        "Null": {
                               "s3:x-amz-server-side-encryption": "true"
                        }
               }
           }
     ]
}
POLICY
}

resource "aws_s3_bucket_public_access_block" "block_public_access_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#Main region
resource "aws_iam_role" "terraform_state" {
  name               = "terraform_state"
  assume_role_policy = data.aws_iam_policy_document.terraform_state.json
}

data "aws_iam_policy_document" "terraform_state" {
  statement {
    sid    = "AllowList"
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "AWS"
      identifiers = local.accounts
    }
  }
}

resource "aws_iam_role_policy" "terraform_state-update" {
  name = "terraform_state-update"
  role = aws_iam_role.terraform_state.id

  policy = <<POLICY
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Action":[
            "s3:ListBucket",
            "s3:GetObject",
            "s3:PutObject"
         ],
         "Effect":"Allow",
         "Resource":[
            "arn:aws:s3:::${local.bucket_name}",
            "arn:aws:s3:::${local.bucket_name}/*"
         ]
      },
      {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "${aws_dynamodb_table.dynamodb-terraform_state-lock.arn}"
      },
      {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "${aws_kms_key.terraform.arn}"
      }
   ]
}
POLICY
}
