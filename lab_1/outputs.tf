output "terraform_state_kms" {
  value = aws_kms_key.terraform.arn
}

output "terraform_state_role" {
  value = aws_iam_role.terraform_state.arn
}

output "root_module_state_tfvars_json" {
  value = <<-EOF
{
	"bucket": "${aws_s3_bucket.bucket.id}",
	"dr_region": "${var.replica_region}",
	"dynamodb_table": "${aws_dynamodb_table.dynamodb-terraform_state-lock.id}",
	"encrypt": "true",
	"kms_key_id": "${aws_kms_key.terraform.arn}",
	"region": "eu-central-1",
	"role_arn": "${aws_iam_role.terraform_state.arn}"
}
EOF
}