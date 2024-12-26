
{
    "rules": [
      {
        "rulePriority": 1,
        "description": "Keep last 5 images",
        "selection": {
          "tagStatus": "tagged",
          "tagPrefixList": [ "snapshot" ],
          "countType": "imageCountMoreThan",
          "countNumber": 5
        },
        "action": {
          "type": "expire"
        }
      }
    ]
  }
  