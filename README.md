# DMARCExploreR

DMARCExploreR is a project for analysis of DMARC email reports in R and RStudio. Using R gives us access to first-class statistical analysis and data visualization tools. Understanding and implementing DMARC is something I've needed for some time. This project is the result of me getting a better understanding of DMARC, DKIM, SPF, and everything else involved in email security.

Take a look at the [starter policy](#starter-policy) if you're just getting started with DMARC - this is a great way to dip your toe in without affecting email flow.

### Starter Policy

It doesn't take long to get going if you're starting from square-one and don't have a DMARC policy. If you're starting fresh do these steps first before moving on through the rest of the proejct. We want to start collecting reports ASAP so we have something to analyze later. It will take a day or two for reports to begin arriving from reporting organizations.

The following steps are what I use to bootstrap DMARC for an organization without affecting mail flow:

1. Create an email address to receive reports, e.g. "dmarc@example.com"; I recommend a shared mailbox, rather than a real account like you'd assign to a person.

    NOTE: Don't use your own email address for this. DMARC can generate a LOT of email depending on how many messages your systems send and to how many recipients.

1. Create a bare-bones DMARC policy in your public DNS zone. This configuration is for domain "example.com", and you should substitute your own domain while creating the DNS record:

    * Record type: TXT
    * Record name: _dmarc.example.com
    * Contents: 
        ```
        v=DMARC1; p=none; rua=mailto:dmarc@example.com; ruf=mailto:dmarc@example.com; fo=1;
        ```
    * Record TTL: 3600

1. Give the new record some time to be created in your zone; This may take a few minutes or a few hours depending on your DNS provider.

1. Use a [command-line tool like *nslookup* or *dig* to examine your new record](#checking-policies), and verify it is published in the DNS.

Here is a quick explanation of options in the bootstrap record:

* v=DMARC1: The version of DMARC used (version 1 is the only version as of 2023)
* p=none: Take no action if an email fails validation
* rua=mailto:dmarc@example.com: Send DMARC aggregate reports to *dmarc@example.com*
* ruf=mailto:dmarc@example.com: Send DMARC forensic reports to *dmarc@example.com*
* fo=1: Send an email if *any* message authentication fails

The "fo=1" tag gives us more information for troubleshooting SPF and DKIM failures. It's also just a good idea to collect forensic reports (ruf=... tag). Move on to installing the software using steps below once reports begin to arrive.

## Installation & Configuration

These directions get the project running on Windows. General steps for Mac will work as well, though there may be some slight differences in software operation.

### Dependencies

Follow these steps to install project dependencies:

1. [Download](https://cran.r-project.org/bin/windows/base/) and install R, accepting default options
1. [Download](https://posit.co/download/rstudio-desktop/) and install RStudio, accepting default options
1. [Download](https://cran.r-project.org/bin/windows/Rtools/) and install R Tools, accepting default options
1. Install R packages:
    1. Open RStudio
    1. In the RStudio "Console" window at the bottom-left, run the following command:
        ```
        install.packages(c("xml2","lubridate","tidyverse","arrow","rlog","R.utils"))
        ```

Complete these steps as well if you want to render reports into PDF format:

1. [Download MikTeX](https://miktex.org/download)
1. Install MikTeX, accepting default options
1. Reboot to ensure that MikTeX files are added to PATH

HTML and Word document rendering is available by default in RStudio, but the PDF files look more professional and really look good when printed.

### Clone Repository

Clone this code repository to your local system.

### Copy Reports

Copy DMARC reports in .xml format to the ./Reports/ project directory. This project assumes you have already decompressed the .gz and .zip files that arrive from reporting organizations. [7-Zip](https://www.7-zip.org/download.html) can be used for mass-decompression of files.

If you don't have reports already, create [a bootstrap DMARC record](#starter-policy) and start collecting reports.

## DMARC

Domain-based Message Authentication, Reporting and Conformance (DMARC) authenticates email using [DKIM](#spf), [SPF](#spf), and [policies](#policy) that senders publish for their domain in the [DNS](#dns). Recipient systems compare received emails against published DMARC policies for the sender and then decide whether or not to deliver the message. This is a complementary mechanism to spam, IP, and domain reputation filtering.

### DNS

DMARC policies are published in the public DNS. Using the DNS gives receiving systems a standardized, globally-accessible way of looking up your DMARC policies using name records. DMARC records are required to have a "_dmarc." prefix. DMARC records must also be of the "TXT" type. Using 7-Eleven.com as an example, we know to look for "_dmarc.7-eleven.com" as a TXT record, assuming that the "7-eleven.com" domain is used to send email. 

If 7-Eleven used a subdomain like "mail.7-eleven.com", then they would create a "_dmarc.mail.7-eleven.com" TXT record instead. If mail is sent from a subdomain for which no _dmarc record exists, then the receiving system will reference the parent domain's _dmarc record instead.

We can use command-line tools like *nslookup* and *dig* to check DMARC records for a domain, or a third-party tool like [MXToolbox.com](https://mxtoolbox.com/DMARC.aspx).

### Checking Policies

On Windows, we can use the *nslookup* command to check records in the DNS. On Linux, we can use *dig*. I'm using the 7-Eleven.com domain to demonstrate as of late 2023. From Windows, set the record type to "TXT" and search for the standard "_dmarc." record:

```terminal
nslookup -type=TXT _dmarc.7-eleven.com
```

That gives us the following, as of December 2023:

```
_dmarc.7-eleven.com text =
"v=DMARC1; p=quarantine; (...output omitted...)"
```

On Linux, using the *dig* command with the same options shows the same result:

```
dig -t TXT _dmarc.7-eleven.com
```

Gives us the following, again as of December 2023:

```
;; ANSWER SECTION:
_dmarc.7-eleven.com. 600 IN TXT "v=DMARC1; p=quarantine; (...output omitted...)"
```

### Tags

DMARC options are specified in policy using tags. Many of the tags are optional, and the [RFC details](https://www.rfc-editor.org/rfc/rfc7489#section-6.3) what the default values are if those tags are omitted. Tags are one to three letters, followed by an equals sign, then the tag's value, and a semicolon to finish. Using a previous example, 7-Eleven.com's policy (p) tag is set to Quarantine (p=quarantine). Policy is one of the few mandatory tags in a DMARC record.

Reference [section 6.3 in RFC-7489 for a detailed list of tags](https://www.rfc-editor.org/rfc/rfc7489#section-6.3), whether they are required, and what default values are assumed if the tag is omitted.

### Disposition

Messages sent from an organization with published DMARC policies can have one of three "dispositions" assigned, depending on what criteria they match and what is configured in the policy. These are the three possible dispositions, listed in increasing severity of response to a received message:

1. None
1. Quarantine
1. Reject

None is typically used when first starting DMARC implementation. No action is taken by the receiving system, other than sending a DMARC report back to the sender. Quarantine is an intermediate step, with messages that fail DMARC validation "quarantined", or sent to the recipient's Junk folder. There is no prescribed quarantine response for receiving systems, and some may choose not to deliver a message depending on other factors like sender reputation or spam policies. Reject does exactly what the name says - messages will not be delivered if they fail DMARC.

You can see what disposition is set in a DMARC record by looking for the "p=" [policy](#policy) tag. We already saw that 7-Eleven.com uses Quarantine as of late 2023.

## DKIM

## SPF
