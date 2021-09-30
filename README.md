# Shell script to initialize AWS MFA tokens for a session using CLI profiles

A common setup for companies (and one recommended by AWS) is to always use MFA (Multi Factor Authentication)
to access AWS services. Since logging in with MFA can only be done interactively, getting credentials for
testing applications against AWS services is only possible by using the STS temporary credentials.
This script is meant to simplify this process by using credentials from an AWS CLI profile to get MFA authentication
and using that access to get an STS token which is then set for another profile. This second profile can then be
used by applications (either explicitly, or by overwriting the `default` profile) to get access to AWS services.

# Setup

Create the initial AWS CLI profile (the one that will be used to authenticate with MFA, `mfa_dev` will be used
as an example) by either manually creating the file `~/.aws/credentials` and setting it up according to documentation,
or by using `aws configure --profile mfa_dev`. Afterwards, run the script with `./aws-mfa-login.sh --dest-profile dev`
(or your name for the profile to use, default is `default` and the examples will use `dev`) each time temporary
credentials will be needed, specifying `mfa_dev` as the source profile. If the script is successful, `dev` profile
will hold the temporary credentials that will not require MFA to use.

If you do not wish to have to enter the username or AWS account number (for example) every time, it is recommended
to set up an alias to do that for you. All values that are passed via interactive prompts can be passed via CLI arguments
instead. Assuming the script is placed in `~/aws_mfa_terminal_initializer/aws-mfa-login.sh`, you can create aliases
similar to these:
```bash
alias aws-login-dev='~/aws_mfa_terminal_initializer/aws-mfa-login.sh -s mfa_dev -p dev -u john.doe -a 123456789012'
alias aws-login-prod='~/aws_mfa_terminal_initializer/aws-mfa-login.sh -s mfa_prod -p prod -u john.doe -a 345678901234'
alias aws-login-default='~/aws_mfa_terminal_initializer/aws-mfa-login.sh -s mfa_dev -p default -u john.doe -a 123456789012'
```
To make the aliases permanent, add them to `~/.bashrc` or equivalent for your shell if it is not `bash`.
