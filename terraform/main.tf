provider "google" {
    credentials = "${file("credentials.json")}"
    project     = var.project_id
    region      = var.region
    zone        = var.zone
}

data "template_file" "init_script" {
    template = file("init_script_template.sh")
    vars = {
        db_password = var.db_password
        subdomain = "life-booster-${var.environment}.${data.google_dns_managed_zone.base_domain.dns_name}"
    }
}

resource "google_compute_instance" "base_instance" {
    name = "life-booster-${var.environment}"
    machine_type = "g1-small"

    boot_disk {
        initialize_params {
            image = "gce-uefi-images/ubuntu-1804-lts"
        }
    }

    tags = [ "web" ]

    labels = {
        environment = var.environment
    }

    metadata_startup_script = data.template_file.init_script.rendered

    network_interface {
        access_config {
            network_tier = "PREMIUM"
        }
        network = "default"
    }
}

resource "google_storage_bucket" "image_store" {
    name     = "life-booster-${var.environment}"
    location = var.region
    force_destroy = true

    labels = {
        environment = var.environment
    }

    storage_class = "REGIONAL"
}

resource "google_storage_bucket" "thumbnail_store" {
    name     = "life-booster-${var.environment}-thumbnails"
    location = var.region
    force_destroy = true

    labels = {
        environment = var.environment
    }

    storage_class = "REGIONAL"
}

resource "google_storage_bucket" "functions_source" {
  name = "functions_source_${var.environment}"
}

data "archive_file" "thumbnail_generator" {
  type        = "zip"
  source_dir  = "${var.root_dir}/src/main/functions/thumbnail_generator"
  output_path = "${var.build_dir}/thumbnail_generator.zip"
}

resource "google_storage_bucket_object" "generate_thumbnail_source" {
  name   = "generate_thumbnail_source.zip"
  bucket = "${google_storage_bucket.functions_source.name}"
  source = data.archive_file.thumbnail_generator.output_path
}

resource "google_cloudfunctions_function" "generate_thumbnail" {
    name                  = "generate_thumbnail_${var.environment}"
    description           = "Function to generate thumbnails from uploaded photos."
    runtime               = "nodejs10"
    entry_point           = "generate_thumbnail_${var.environment}"

    available_memory_mb   = 256

    source_archive_bucket = google_storage_bucket.functions_source.name
    source_archive_object = google_storage_bucket_object.generate_thumbnail_source.name

    environment_variables = {
        FUNCTION_NAME    = "generate_thumbnail_${var.environment}"
        THUMBNAIL_BUCKET = "${google_storage_bucket.thumbnail_store.name}"
    }

    event_trigger {
        event_type = "google.storage.object.finalize"
        resource   = google_storage_bucket.image_store.name
    }

    labels = {
        environment = var.environment
    }
}

data "google_compute_network" "default" {
  name = "default"
}

resource "google_compute_firewall" "web_traffic" {
    name    = "web-traffic"
    network = data.google_compute_network.default.name

    allow {
        protocol = "tcp"
        ports    = ["80", "443"]
    }

    target_tags = [ "web" ]
}

data "google_dns_managed_zone" "base_domain" {
  name = var.base_domain_zone_name
}

resource "google_dns_record_set" "environment_domain" {
    name = "life-booster-${var.environment}.${data.google_dns_managed_zone.base_domain.dns_name}"
    type = "A"
    ttl  = 60

    managed_zone = "${data.google_dns_managed_zone.base_domain.name}"

    rrdatas = ["${google_compute_instance.base_instance.network_interface.0.access_config.0.nat_ip}"]
}
