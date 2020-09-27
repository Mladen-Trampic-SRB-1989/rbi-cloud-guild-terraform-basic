locals {
  accounts = distinct(concat([data.aws_caller_identity.current.account_id], var.accounts))
}

resource "aws_iam_role" "some_mailintent_role" {
  name               = "some_mailintent_role"
  assume_role_policy = data.aws_iam_policy_document.some_mailintent_role.json
}

data "aws_iam_policy_document" "some_mailintent_role" {
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

resource "aws_iam_role_policy_attachment" "some_mailintent_role" {
  role       = aws_iam_role.some_mailintent_role.id
  #policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}