variable "defaults" {
  description = "Default values applied to every item in `items`, unless that item overrides them. Accepts any input the root module accepts"
  type        = any
  default     = {}
}

variable "items" {
  description = "Map of audit log sinks to manage. Each key becomes an instance of the module and each value accepts any input the root module accepts. An account has at most one audit log sink, so more than one enabled item per account will conflict — see the wrapper README"
  type        = any
  default     = {}
}
