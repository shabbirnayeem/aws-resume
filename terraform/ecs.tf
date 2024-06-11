resource "aws_ecs_cluster" "app_cluster" {
  name = "portfolio-app-cluster"
}

resource "aws_ecs_task_definition" "app_task" {
  family = "portfolio-app-task"
  container_definitions = jsonencode([
    {
      name      = "portfolio-app-container"
      image     = "${aws_ecr_repository.app_repo.repository_url}:latest"
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [{
        containerPort = 9123
        hostPort      = 9123
      }]
    }
  ])

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 2048
  cpu                      = 1024

  execution_role_arn = data.aws_iam_role.ecsTaskExecutionRole.arn
  # task_role_arn      = aws_iam_role.ecs_task_execution_role.arn

}

resource "aws_ecs_service" "app_service" {
  name                              = "portfolio-app-service"
  cluster                           = aws_ecs_cluster.app_cluster.id
  task_definition                   = aws_ecs_task_definition.app_task.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  enable_ecs_managed_tags           = true
  health_check_grace_period_seconds = 5
  wait_for_steady_state             = false

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [data.aws_subnet.subnet-a.id, data.aws_subnet.subnet-b.id]
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "portfolio-app-container"
    container_port   = 9123
  }
}