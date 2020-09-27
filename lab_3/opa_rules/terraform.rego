package terraform.analysis

import input as tfplan

#########
# Policy
#########

# Authorization holds if for the plan there is no Administrator policy attached
default authz = false
authz {
    not is_anyone_trying_to_be_admin
}
resource_types = {"aws_iam_role_policy_attachment"}
# Compute the score for a Terraform plan as the weighted sum of deletions, creations, modifications

resources[resource_type] = all {
    some resource_type
    resource_types[resource_type]
    all := [name |
        name:= tfplan.resource_changes[_]
        contains(name.change.after.policy_arn ,"AdministratorAccess")
    ]
}

# Whether there is any change to IAM
is_anyone_trying_to_be_admin {
    all := resources["aws_iam_role_policy_attachment"]
    count(all) > 0
}


