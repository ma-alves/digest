resource "aws_lambda_layer_version" "shared" {
  layer_name          = "${var.name_prefix}-shared"
  filename            = var.layer_zip_path
  compatible_runtimes = ["nodejs24.x"]
  source_code_hash    = filebase64sha256(var.layer_zip_path)
}
