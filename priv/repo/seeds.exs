alias Wizard.Repo
alias Wizard.Blogs.Log

log = %Log{
  name: "Test Log",
  email_address: "c114c6cf8d66802c5e2f@cloudmailin.net"
}

Repo.insert!(log)
