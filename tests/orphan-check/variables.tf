variable "sink_name" {
  description = "Name of the audit log sink to look for. Empty — the default — checks nothing and reports no orphans, which is correct while the suite creates no sink. Supply a name after creating one by hand to confirm it was cleaned up"
  type        = string
  default     = ""
}
