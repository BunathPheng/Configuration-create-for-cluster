# GCP External Load Balancer -> Traefik (entry point)
# Passthrough NLB: external port 80/443 = same port on VM (must match Traefik hostPort)

resource "google_compute_address" "ingress" {
  name   = "k8s-ingress-ip"
  region = var.region
}

resource "google_compute_instance_group" "workers" {
  name      = "k8s-workers-lb"
  zone      = var.zone
  instances = [for name, _ in var.worker_nodes : google_compute_instance.node[name].self_link]

  named_port {
    name = "http"
    port = 80
  }

  named_port {
    name = "https"
    port = 443
  }
}

resource "google_compute_region_health_check" "traefik_http" {
  name   = "traefik-http-health"
  region = var.region

  tcp_health_check {
    port = 80
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

resource "google_compute_region_backend_service" "traefik_http" {
  name                  = "traefik-http-backend"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_region_health_check.traefik_http.id]

  backend {
    group          = google_compute_instance_group.workers.id
    balancing_mode = "CONNECTION"
  }
}

resource "google_compute_region_backend_service" "traefik_https" {
  name                  = "traefik-https-backend"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_region_health_check.traefik_http.id]

  backend {
    group          = google_compute_instance_group.workers.id
    balancing_mode = "CONNECTION"
  }
}

resource "google_compute_forwarding_rule" "traefik_http" {
  name                  = "traefik-http-rule"
  region                = var.region
  load_balancing_scheme = "EXTERNAL"
  backend_service       = google_compute_region_backend_service.traefik_http.id
  ip_address            = google_compute_address.ingress.address
  ports                 = ["80"]
}

resource "google_compute_forwarding_rule" "traefik_https" {
  name                  = "traefik-https-rule"
  region                = var.region
  load_balancing_scheme = "EXTERNAL"
  backend_service       = google_compute_region_backend_service.traefik_https.id
  ip_address            = google_compute_address.ingress.address
  ports                 = ["443"]
}

resource "google_compute_firewall" "lb_health_check" {
  name    = "k8s-allow-lb-health-check"
  network = google_compute_network.k8s.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["k8s-node"]
}
