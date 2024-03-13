# DMARCExploreR

DMARCExploreR is a project for analysis of DMARC email reports in R and RStudio. It's meant to take you from zero to robust analysis in hardly any time at all. Using [R](https://www.r-project.org/) gives us access to first-class statistical analysis and data visualization tools. Data in the exported [Parquet files](https://parquet.apache.org/) can be analyzed further in PowerBI, Excel, Tableau, RStudio, or other mainstream data analysis platforms.

Take a look at the [starter policy](#starter-policy) section if you're just getting started with DMARC - this is a great way to dip your toe in without affecting email flow.

## Motivation

Gaining a deep understanding of DMARC and new trends in email security is something I've needed to do for some time. I'd procrastinated, because SPF, DKIM, DMARC, and how they all work together is just *a lot*. This project is the result of me getting a better understanding of all that, how it all works together, and what good email security looks like. This project is equal parts documentation for myself, giving back to the technology community, and scratching the itch for a new data-oriented project.

## Starter Policy

It doesn't take long to get going if you're starting from square-one and don't have a DMARC policy. You don't need to have SPF and DKIM fully configured to start collecting reports. If you're starting fresh do these steps first before moving on through the rest of the proejct. We want to start collecting reports ASAP so we have something to analyze later. It will take a day or two for reports to begin arriving from reporting organizations.

The following steps are what I use to bootstrap DMARC for an organization without affecting mail flow:

1. Create an email address to receive reports, e.g. "dmarc@example.com"; I recommend a shared mailbox, rather than a real account like you'd assign to a person.

    **NOTE**: Do **NOT** use your own email address for this. DMARC can generate a LOT of email depending on how many messages your systems send and to how many recipients.

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

* v=DMARC1: The version of DMARC used (version 1 is the only version as of 2024)
* p=none: Take no action if an email fails validation
* rua=mailto:dmarc@example.com: Send DMARC aggregate reports to *dmarc@example.com*
* ruf=mailto:dmarc@example.com: Send DMARC forensic reports to *dmarc@example.com*
* fo=1: Send an email if *any* message authentication fails

The "fo=1" tag gives us more information for troubleshooting SPF and DKIM failures. The default is only to send a report if SPF *and* DKIM fail. That's great once you've completed implemenation, but not for getting started. 

It's also just a good idea to collect forensic reports (ruf=... tag). Hopefully you rarely (if ever) receive a forensic report.

At this point, if you're just getting started, it's good to remember to be **patient**. It will likely take 24hrs for reports to begin trickling in, depending on what time of day you created the "_dmarc.example.com" record. It will take probably another couple days to gather enough DMARC reports to really start analysis. If you send weekly newsletters, monthly statements, or other infrequent communications, those won't show up in your DMARC reports yet either. *Be patient and set expectations for DMARC project progress appropriately.*

Move on to installing the software using steps below once reports begin to arrive.

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
        install.packages(c("xml2","lubridate","tidyverse","knitr","arrow","rlog","R.utils"))
        ```
    1. If prompted, select "Yes" for compiling packages from source or using a personal library

1. Complete these steps as well if you want to render reports into PDF format (not necessary to get started):
    1. [Download MikTeX](https://miktex.org/download)
    1. Install MikTeX, accepting default options
    1. Reboot to ensure that MikTeX files are added to PATH

HTML and Word document rendering is available by default in RStudio, but the PDF files look more professional and really look good when printed.

### Clone Repository

Clone this code repository to your local system.

### Copy Reports

Hopefully by this point you've been collecting DMARC reports for a few days and have data to analyze. Follow these steps to move the XML files prior to analysis:

1. Decompress all .gz and .zip DMARC report files ([7-Zip](https://www.7-zip.org/download.html) is great for mass-decompression)
1. Copy decompressed directories and XML files to the /Reports/ project directory

If you don't have reports already, create [a bootstrap DMARC record](#starter-policy) and start the collection process.

### Run R Code

1. Double-click the DMARCExploreR.rproj file in the /RCode/ project directory. This will launch RStudio.
1. In the lower-right window, select the "Files" tab, and open the ParseReports.R file.
1. Run the R code to parse the .XML files, using one of these methods:
    1. In the task bar above the R code, click the "Source" dropdown, then click the "Source" option
    1. While clicked in the window with R code, press Ctrl+Shift+S to run all code
    1. While clicked in the window with R code, press Ctrl-A to select everything, then Ctrl-Enter to run the selected code
1. Wait for parsing to complete
1. Once completed, check the /Parquet/ directory to verify that an export file is present
1. Move on to the Analysis phase

### Analysis

This section is pending.

## DMARC

Domain-based Message Authentication, Reporting and Conformance (DMARC) authenticates email using [DKIM](#spf), [SPF](#spf), and [policies](#policy) that senders publish for their domain in the [DNS](#dns). Recipient systems compare received emails against published DMARC policies for the sender and then decide whether or not to deliver the message. This mechanism is complementary to spam, IP, and domain reputation filtering.

There are a number of things that DMARC does *not* do, and it's important to bear them in mind. DMARC does not:

1. Filter spam
1. Protect against business email compromise (BEC)
1. Encrypt messages

Other solutions are responsible for the items listed above.

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

DMARC options are specified in policy using tags. Many of the tags are optional, and the [RFC details in section 6.3](https://www.rfc-editor.org/rfc/rfc7489#section-6.3) what the default values are if those tags are omitted. Tags are one to three letters, followed by an equals sign, then the tag's value, and a semicolon to finish. Using a previous example, 7-Eleven.com's policy (p) tag is set to Quarantine (p=quarantine). Policy is one of the few mandatory tags in a DMARC record.

Reference [section 6.3 in RFC-7489 for a detailed list of tags](https://www.rfc-editor.org/rfc/rfc7489#section-6.3), whether they are required, and what default values are assumed if the tag is omitted. 

**NOTE**: Most of the tags have sensible default values and don't need tweaking unless you're really looking to fine-tune DMARC reporting.

### Policy

One of three "policies" can be assigned by email senders, depending on how they want receivers to treat emails that don't pass both SPF and DKIM validation. These are the three possible dispositions, listed in increasing severity of response:

1. None
1. Quarantine
1. Reject

*None* is typically used when first starting DMARC implementation. No action is taken by the receiving system when both SPF and DKIM validation fail, other than sending a DMARC report back to the sender. *Quarantine* is an intermediate step, with messages that fail DMARC validation "quarantined", or sent to the recipient's Junk folder. There is no prescribed quarantine response for receiving systems, and some may choose not to deliver a message depending on other factors like sender reputation or spam policies. *Reject* does exactly what the name says - messages will not be delivered at all. An error message is typically sent back to the sender notifying them of the rejection, but that depends on the mail processing system.

You can see what disposition is set in a DMARC record by looking for the "p=" [policy](#policy) tag. We already saw that 7-Eleven.com uses Quarantine as of late 2023.

### Receiver Implementation Flexibility

It's important to note that systems receiving your email aren't required to strictly follow your published DMARC policy. Section 6.7 of the RFP states, "*Mail Receivers MAY choose to reject or quarantine email even if email passes the DMARC mechanism check.*", and, "*Mail Receivers MAY choose to accept email that fails the DMARC mechanism check even if the Domain Owner has published a 'reject' policy.*", and, "*Final disposition of a message is always a matter of local policy.*" Receivers can blend DMARC policy and email threat intelligence to come to their own decision of how best to handle received emails.

Receivers are also not required to strictly follow the reporting interval (RI) tag. The RFP requires email receivers running DMARC to be prepared to report AT LEAST once every 24hrs. Reporting more often is nice, but not required. Receivers are also, "strongly encouraged to begin [the reporting] period at 00:00 UTC, regardless of local timezone or time of report production, in order to facilitate correlation." 

## DKIM

[DomainKeys Identified Mail (DKIM)](https://en.wikipedia.org/wiki/DomainKeys_Identified_Mail) digitally signs messages. This isn't encryption, but it does validate that an email came from an authorized sender and it wasn't tampered with along the way. A sender's email system signs outbound messages with a private key that is kept secret. Receiving email systems validate that signature with a public key published in a DNS TXT record.

An attacker trying to spoof emails can't duplicate that digital signature because they lack the private key that an authorized sender would use for signing. Emails failing DKIM validation can indicate a couple things:

* A system is sending emails that isn't accounted for in the DKIM configuration
* The wrong key was published in DNS, or incorrectly selected in the signing system
* An attacker is attempting to spoof emails from the sender's domain

DKIM is, unfortunately, more complex to configure than SPF. System administrators should familiarize themselves with key generation and handling best practices. Adding to that complexity, it is recommended that organizations cycle DKIM keys periodically to increase security.

## SPF

[Sender Policy Framework (SPF)](https://en.wikipedia.org/wiki/Sender_Policy_Framework) is a method of authenticating emails. Systems that are authorized to send emails for a domain are listed in a DNS TXT record. An email arriving at a receiving system from a sender with an IP address or hostname not listed in the TXT record will fail SPF validation.

Failed SPF validation can indicate a few things:

* A system is sending emails that isn't accounted for in the DKIM configuration
* An internal or external sender has added a new IP range but hasn't updated their SPF record
* An SPF record isn't configured properly in DNS
* An attacker is attempting to spoof emails from the domain

An SPF record for example.com might look like this:

```
v=spf1 mx include:spf.pretendemailrelay.com ip4:1.1.1.1 ip4:2.2.2.2 -all
```

Emails from example.com can come from any hostname or IP address listed in spf.pretendmailrelay.com, and from IP addresses 1.1.1.1 and 2.2.2.2. The "-all" option at the end of the record tells the receiver to reject any messages that came from other systems not listed. 

## FAQ

1. **Why use R instead of {$language or $platform}?** R is amazing. It's one of the *very* few technologies considered to be appropriate for medical trial statistical analysis. While Python is the trendy tool for data analysis, much of the popular libraries for working with data in Python simply duplicate R functionality. I say that as someone who has written a lot of Python code and enjoys working with it. But for statistical analysis and data wrangling, R is my go-to. It's well-known and trusted in communities where rigor and reproducibility are valued highly. Folks can always import .parquet files into a different solutions if they're not in love with R or the Tidyverse. 

1. **Do you accept pull requests?** As of now, no. I don't have the time to vet new code or features as things stand. I'm happy to address issues if people discover them, but I don't have time for ordinary pull requests.

## Contact
Email tyler[[@]]dmarcexplorer.com if you have questions or comments. Thanks!

## Copyright
Copyright 2024, Tyler Hart. All rights reserved. See the LICENSE.md file for more information on usage rights and restrictions.
