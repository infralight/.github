resource "google_compute_snapshot" "instance-test-us-central1-b-20251230164241-qt8ov735" {
  name              = "instance-test-us-central1-b-20251230164241-qt8ov735"
  project           = "development-389209"
  source_disk       = "https://www.googleapis.com/compute/v1/projects/development-389209/zones/us-central1-b/disks/instance-test"
  storage_locations = ["us"]
}

