# IAM Infrastructure Prototype

Code for a fictional startup to explain how governance, risk management, and
compliance (GRC), cybersecurity, and infrastructure automation can benefit from
the use of HR-Driven Identity Lifecycle and other Identity and Access Management
practices.

- [📝 Notice](#-notice)
- [📜 Introduction](#-introduction)
  - [Stakeholders](#stakeholders)
  - [Workforce IAM](#workforce-iam)
    - [HR-Driven Identity Lifecycle](#hr-driven-identity-lifecycle)
    - [Application Lifecycle Management (ALM) connected with the Asset Catalog](#application-lifecycle-management-alm-connected-with-the-asset-catalog)
    - [Automated Provisioning](#automated-provisioning)
    - [Procedure and Processes](#procedure-and-processes)
- [🐣 Getting started](#-getting-started)
  - [⚙️ Setup](#️-setup)
    - [Dependencies](#dependencies)
    - [Generate and provision instances](#generate-and-provision-instances)
  - [💻 Linux desktop Instance](#-linux-desktop-instance)
    - [Connect using Remote Desktop](#connect-using-remote-desktop)
    - [Test self-signed certificates](#test-self-signed-certificates)
    - [Complete Setup](#complete-setup)
      - [Configure Forgejo ssh keys](#configure-forgejo-ssh-keys)
  - [🧑‍💻 Access Kubernetes cluster](#-access-kubernetes-cluster)
    - [Connecting from the console](#connecting-from-the-console)
    - [Connect using linux-desktop browser](#connect-using-linux-desktop-browser)
      - [Traefik Dashboard](#traefik-dashboard)
      - [Kubernetes Dashboard](#kubernetes-dashboard)
- [🧑‍🔧 Troubleshooting](#-troubleshooting)
- [🔧 Development](#-development)
- [🔖 Resources](#-resources)
  - [IAM, IGA, CIAM, and Zero Trust architecture](#iam-iga-ciam-and-zero-trust-architecture)
  - [Accessibility Directives and Guidelines](#accessibility-directives-and-guidelines)
  - [Compliance As Code](#compliance-as-code)
  - [Frameworks and Regulations](#frameworks-and-regulations)
  - [Standard Notations](#standard-notations)
- [📄 Licenses](#-licenses)

## 📝 Notice

You can see [screenshots](docs/screenshots.md) of some of the applications
that will be provisioned with the current setup.

This project is ambitious and constantly evolving.

In the [To Do](docs/TODO.md) document you can find what has been implemented
and what is planned.

## 📜 Introduction

### Stakeholders

The implementation of a proper IAM infrastructure requires the involvement of
people from different teams and departments. Underestimating the need to involve
all stakeholders at an early stage will lead to delays, waste of money and
resources, and poor adoption.

The following is an incomplete list of candidate stakeholders:

- Human Resources (HR)
  - People operations
  - Talent acquisition
  - Talent management
  - Diversity, Equity, and Inclusion (DEI)
- Governance, Risk management and Compliance (GRC)
  - Information Security (especially the CISO)
  - Data Protection Officer
  - Compliance Officers
  - Risk Management
  - Internal Auditors
  - Legal team
  - Financial risk
- Information Technology
  - CTO
  - Software Architects
  - Cyber Security
  - Site Reliability Engineering (SRE)
  - Platform
  - Business Application Owners
  - Engineering Managers

### Workforce IAM

#### HR-Driven Identity Lifecycle

The HR department is the one that knows who is joining, who is leaving, who is
moving to another job within the company, who is on vacation, sick leave, parental
leave, etc. Their system should expose for each employee at least the name that
should be used for them within the company (might be different from their legal
name, which is only required by HR to sign contracts), the start and end dates
(if applicable) of the contract, department, role, line manager, and absences.

Their database should be the source of truth for identities in the workforce. Other
sources of truth can exist, but there must be a good reason for the exception.
Furthermore, for such sources there needs to be an owner and at least one deputy
responsible for the identities, and the identities need to be marked as “untrusted”
and have a label with the source to help the Information Security team evaluate
any access requests to internal systems.

#### Application Lifecycle Management (ALM) connected with the Asset Catalog

It is not possible to automate access to applications without knowing whether the
application is in review, ready to be used or about to be decommissioned, who the
Asset Owner is, what roles can be assigned to users, etc.

All applications and services must reside in an Asset Catalog, be labeled with the
appropriate status and Information Assurance (IA) levels, and have assigned Asset
Owners (and deputies), Application Administrators, and Infrastructure Administrators.

When selecting new applications and services, ensure that new systems have an
appropriate interface for automated provisioning, preferring systems with SAML,
SCIM, OpenID Connect, OAuth or at least appropriate API endpoints (or even better
a supported connector for your IGA. See [Evolveum Identity Connectors and Resources][evolveum-connectors]
as an example).

#### Automated Provisioning

The HR department can provide us with some information about employees, but it
is up to the Line Manager, with the help of the Asset Owners (and the Information
Security team when in doubt), to determine which roles to assign them for day-to-day
work (and it is preferable to use Profiles that aggregate access, e.g., a person
working on a project will need access to the relevant chat channels, project emails,
related services, etc.).

All access and communication channels necessary for people's daily work should be
granted according to their profiles during on-boarding, based on their employment
relationship, location, sub-company, department, their role in the teams, projects
to which they are assigned, etc.

The exclusive use of RBAC to grant people access to services and applications will
lead to a proliferation of roles that will quickly become unmanageable. My advice
is to use a Policy-Based approach in a Zero Trust architecture.

All administrative access must be granted using short just-in-time credentials
that needs approval. The approval process can be automated for exceptional cases
using policies (e.g., an on-call engineer needs to work on a service they are
assigned to during an incident).

#### Procedure and Processes

Many procedures and processes will benefit from a well-built IAM infrastructure.

These include, but are not limited to:

- Business Continuity
- Disaster Recovery
- Internal Audit

## 🐣 Getting started

This project will create and provision 3 instances:

- an [ansible][ansible] controller (also used to host the internal DNS server)
- a [Kubernetes][kubernetes] cluster (a single instance for now)
- a Linux desktop with [Xfce Desktop Environment][xfce]

> **Warning**
>
> To keep the code as clean as possible, for the time being, this project is not
> designed to be backward compatible.
>
> Instances are expected to be destroyed and recreated as new code may rename,
> remove, or modify resources in ways that could break previous deployments.

### ⚙️ Setup

#### Dependencies

- [Jsonnet][jsonnet]
- [Multipass][multipass] or [VirtualBox][virtualbox]

#### Generate and provision instances

The `project-management` script manages the creation, provisioning, and deletion
of instances.

Run `./project-management --help` to get a list of options.

To execute all required steps, you can run:

```sh
./project-management --all
```

The script will prompt for a password (and confirmation) to be used for the
instances administrator user.

To avoid being prompted for the password, you can create the file
`generated/assets/passwords/admin/plain` or set the environment variable
`INSTANCE_ADMIN_PASSWORD`.

```sh
INSTANCE_ADMIN_PASSWORD=changeme ./project-management -a
```

The `-a` (or `--all`) option will perform all required steps sequentially.

By default, the script will use [multipass][multipass] and the host architecture,
essentially the command `./project-management -a` is equivalent to running:

```sh
./project-management -o multipass -a "$(uname -m)" -g -c -b -w -p
```

If you want more control, you can perform the steps in groups or one at a time:

e.g.:

```sh
./project-management --generate --configure
./project-management --bootstrap
./project-management --wrap-up
./project-management --provision
```

#### Delete instances

The `--delete` option will remove instances and related volumes, but keep the
generated scripts and instances configuration.

```sh
./project-management --delete
```

To delete the local project folder, generated scripts, and instances configuration,
use the `--purge` option alongside `--delete`.

```sh
./project-management --delete --purge
```

### 💻 Linux desktop Instance

#### Connect using Remote Desktop

Use any RDP client, such as [Windows App][microsoft-windows-app] (formerly known
as [Microsoft Remote Desktop][microsoft-remote-desktop]) or [FreeRDP][freerdp],
to connect to the `linux-desktop` instance.

- user: **ubuntu**
- password: **ubuntu**

The IP Address is the first entry from `ipv4` when running the following command:

```sh
./platform/project-script-generator/generated/instances-status.sh linux-desktop
```

#### Test self-signed certificates

The ansible scripts should have installed the self-signed root certificate
inside the linux-desktop instance.

To test that the services are using the proper DNS and certificates, open a
terminal in `linux-desktop` and type:

```sh
~/bin/check-instance-config.sh
```

The result should be similar to the [OpenSSL Checks](./docs/screenshots.md#openssl-checks)
screenshot.

#### Complete Setup

> **Note:** required to run only once

##### Configure Forgejo ssh keys

Open a terminal to generate the ssh keys.

```sh
ssh-keygen -t ed25519 -C "ubuntu@iam-demo.test"
```

Open a [Forgejo](https://git.iam-demo.test) in a browser and login using the
credentials from [Connect using linux-desktop browser](#connect-using-linux-desktop-browser).

Open a terminal and copy your public ssh key in the clipboard.

```sh
cat ~/.ssh/id_ed25519.pub | tee >(xclip -selection clipboard); echo ''
```

Open [Manage SSH Keys in Forgejo](https://git.iam-demo.test/user/settings/keys)
in a browser and paste the public key.

### 🧑‍💻 Access Kubernetes cluster

#### Connecting from the console

Access `ansible-controller` shell using:

```sh
./platform/project-script-generator/generated/instance-shell.sh ansible-controller
```

or connect to `linux-desktop` [using Remote Desktop](#connect-using-remote-desktop)
and open a terminal.

You can also access `linux-desktop` shell using:

```sh
./platform/project-script-generator/generated/instance-shell.sh linux-desktop
```

To check the Kubernetes configuration, type:

```sh
kubectl config view
```

The output should be like the following:

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://iam-control-plane.iam-demo.test:6443
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: default
  user:
    client-certificate-data: DATA+OMITTED
    client-key-data: DATA+OMITTED
```

The [kubernetes](kubernetes/) folder is mounted inside the `ansible-controller`
under `/kubernetes`.

#### Connect using linux-desktop browser

Connect to `linux-desktop` [using Remote Desktop](#connect-using-remote-desktop).

Open Firefox inside the instance, and use the following URLs:

> **Note:** You can also find them in the Firefox Bookmarks Toolbar under
> "Managed bookmarks".

- Grafana: <https://grafana.iam-demo.test>
  - user: admin
  - password: grafana-admin
- Forgejo: <https://git.iam-demo.test>
  - user: forgejo-admin
  - password: forgejopw123!
- Prometheus: <https://prometheus.iam-demo.test>
- Alertmanager: <https://alertmanager.iam-demo.test>
- Consul: <https://consul.iam-demo.test>
- Keycloak: <https://keycloak.iam-demo.test>

To access Traefik or Kubernetes dashboards, follow the instructions in the
respective subsections.

##### Traefik Dashboard

Open a terminal and start port forwarding using:

```sh
KUBECONFIG=~/.kube/config-iam-demo-tech
kubectl port-forward \
  --namespace kube-system \
  $(kubectl get pods \
    --namespace kube-system \
    --selector "app.kubernetes.io/name=traefik" \
    --output=name) \
  9000:9000
```

Open <http://127.0.0.1:9000/dashboard/> in a browser.

##### Kubernetes Dashboard

Generate a token, print it and copy it to the clipboard:

```sh
kubectl -n kubernetes-dashboard create token admin-user | tee >(xclip -selection clipboard); echo ''
```

Start the proxy:

```sh
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
```

Access the kubernetes-dashboard in a web browser opening:

<https://localhost:8443/>

## 🧑‍🔧 Troubleshooting

- [Troubleshooting](docs/troubleshooting/README.md)

## 🔧 Development

See [development](docs/development/) documentation.

## 🔖 Resources

Here are some useful links on topics that I consider relevant.

It’s a long and incomplete list.

### IAM, IGA, CIAM, and Zero Trust architecture

Regarding IAM, IGA, CIAM, and Zero Trust architecture, [KuppingerCole][kuppingercole-website]
is a reliable source for an introduction to these topics:

- [The Definitive Guide to Identity & Access Management][kuppingercole-IAM-definitive-guide]
- [Identity Governance and Administration – A Policy-Based Primer for Your Company][kuppingercole-IGA-guide]
- [Customer Identity & Access Management (CIAM)][kuppingercole-CIAM]
- [The Comprehensive Guide to Zero Trust Implementation][kuppingercole-zero-trust-guide]

The [Evolveum][evolveum-website] website also contains a lot of good IAM introductory
concepts:

- [Practical Identity Management with MidPoint][evolveum-book]
- [Identity and Access Management][evolveum-iam]

### Accessibility Directives and Guidelines

- [European Commission - Web Accessibility][ec-web-accessibility]: Overview of
  the European Commission
  Web Accessibility Directive
- [EN 301 549][etsi-EN-301-549]: Accessibility requirements for ICT products and
  services
- [WAI][w3c-wai]: W3C Web Accessibility Initiative
  - [WCAG][w3c-wai-wcag]: Web Content Accessibility Guidelines
  - [ARIA][w3c-wai-aria]: Accessible Rich Internet Applications suite of web standards
  - [ACT][w3c-wai-act]: Accessibility Conformance Testing
  - [EARL][w3c-wai-earl]: Evaluation and Report Language
  - [policies][w3c-wai-policies]: Web Accessibility Laws & Policies

### Compliance As Code

- [SCAP][nist-scap]: Security Content Automation Protocol
- [OpenSCAP][open-scap]: open source security compliance toolkit
  > NIST certified for SCAP 1.2
- [ComplianceAsCode][compliance-as-code-project]: The ComplianceAsCode project
  > Previously known as SCAP Security Guide (SSG)
- [OSCAL][nist-oscal]: Open Security Controls Assessment Language
  - [OSCAL Mini Workshop Series][nist-oscal-workshops]
- [Trestle][trestle]: An opinionated platform to manage compliance as code using
  NIST's OSCAL standard
- [OPA][opa-website]: Open Policy Agent
  > Declarative Policies - Context-aware, Expressive, Fast, Portable
- [OPAL][opal]: Open Policy Administration Layer

### Frameworks and Regulations

- [GDPR][gdpr]: General Data Protection Regulation
- [ISO/IEC 27000][iso-27000]: Information security management systems - Overview
  and vocabulary
- [ISO/IEC 27001][iso-27001]: Information security management systems - Requirements
- [ISO/IEC 24760][iso-24760]: IT Security and Privacy - A framework for identity
  management
- [NIS2 directive][nis2-final]: Network and Information Security Directive
  > EU-wide legislation on cybersecurity
  - [The NIS2 Directive Explained][nis2-explained]
- [KRITIS][kritis-de]: Kritische Infrastrukturen (German)\
  English translation: [Critical Infrastructures][kritis-en]
- [DORA][dora]: Digital Operational Resilience Act
- [BaFin][bafin-de]: Bundesanstalt für Finanzdienstleistungsaufsicht (German)\
  English translation: [Federal Financial Supervisory Authority][bafin-en]
- [MaRisk][marisk-de]: Mindestanforderungen an das Risikomanagement (German)\
  English translation: [Minimum Requirements for Risk Management][marisk-en]
- [BAIT][bait-de]: Bankaufsichtliche Anforderungen an die IT (German)\
  English translation: [Supervisory Requirements for IT in Financial Institutions][bait-en]\
  [Clearer Guidelines as a Basis for More Effective Implementation][kuppingercole-bait]
  (KuppingerCole)
- [MiCA][mica]: Markets in Crypto-Assets Regulation
- [EHDS][ehds]: European Health Data Space
- [eHDSI]: eHealth Digital Service Infrastructure
- [DVG][dvg-en]: Digital Healthcare Act

### Standard Notations

- [BPMN][bpmn]: Business Process Model and Notation
- [DMN][dmn]: Decision Model and Notation

## 📄 Licenses

- Documentation: [CC-BY-4.0](LICENSE-DOCS)
- Code: [Apache-2.0](LICENSE-CODE)

[ansible]: <https://ansible.readthedocs.io/> "Ansible"
[bafin-de]: <https://www.bafin.de/> "BaFin - Bundesanstalt für Finanzdienstleistungsaufsicht"
[bafin-en]: <https://www.bafin.de/EN/> "BaFin -Federal Financial Supervisory Authority"
[bait-de]: <https://www.bafin.de/ref/19595164> "BAIT - Bankaufsichtliche Anforderungen an die IT"
[bait-en]: <https://www.bafin.de/ref/19594854> "BAIT - Supervisory Requirements for IT in Financial Institutions"
[bpmn]: <https://www.omg.org/spec/BPMN> "Business Process Model and Notation"
[compliance-as-code-project]: <https://complianceascode.readthedocs.io/> "ComplianceAsCode project"
[dmn]: <https://www.omg.org/spec/DMN> "Decision Model and Notation"
[dora]: <https://www.eiopa.europa.eu/digital-operational-resilience-act-dora_en> "Digital Operational Resilience Act (DORA)"
[dvg-en]: <https://www.bundesgesundheitsministerium.de/en/digital-healthcare-act> "Digital Healthcare Act – DVG"
[ec-web-accessibility]: <https://digital-strategy.ec.europa.eu/en/policies/web-accessibility> "European Commission - Web Accessibility"
[ehds]: <https://health.ec.europa.eu/ehealth-digital-health-and-care/european-health-data-space_en> "European Health Data Space"
[ehdsi]: <https://health.ec.europa.eu/ehealth-digital-health-and-care/electronic-cross-border-health-services_en> "eHealth Digital Service Infrastructure (eHDSI)"
[etsi-EN-301-549]: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/03.02.01_60/en_301549v030201p.pdf> "EN 301 549 V3.2.1"
[evolveum-book]: <https://docs.evolveum.com/book/> "EVolveum - Practical Identity Management with MidPoint"
[evolveum-connectors]: <https://docs.evolveum.com/connectors/> "Evolveum - Identity Connectors and Resources"
[evolveum-iam]: <https://docs.evolveum.com/iam/> "Evolveum - Identity and Access Management"
[evolveum-website]: <https://evolveum.com/> "Evolveum"
[freerdp]: <https://www.freerdp.com/> "FreeRDP: A Remote Desktop Protocol Implementation"
[gdpr]: <https://gdpr-info.eu/> "General Data Protection Regulation"
[iso-24760]: <https://www.iso.org/standard/77582.html> "ISO/IEC 24760-1:2019"
[iso-27000]: <https://www.iso.org/standard/73906.html> "ISO/IEC 27000"
[iso-27001]: <https://www.iso.org/standard/27001> "ISO/IEC 27001"
[jsonnet]: <https://jsonnet.org> "Jsonnet"
[kritis-de]: <https://www.bsi.bund.de/DE/Themen/Regulierte-Wirtschaft/Kritische-Infrastrukturen/kritis_node.html> "KRITIS - Kritische Infrastrukturen"
[kritis-en]: <https://www.bsi.bund.de/EN/Themen/Regulierte-Wirtschaft/Kritische-Infrastrukturen/kritis_node.html> "KRITIS - Critical Infrastructures"
[kubernetes]: <https://kubernetes.io> "Kubernetes CLI"
[kuppingercole-bait]: <https://www.kuppingercole.com/blog/reinwarth/bait-clearer-guidelines-as-a-basis-for-more-effective-implementation> "KuppingerCole - BAIT: Clearer Guidelines as a Basis for More Effective Implementation"
[kuppingercole-CIAM]: <https://www.kuppingercole.com/insights/customer-identity-and-access-management> "KuppingerCole - Customer Identity & Access Management"
[kuppingercole-IAM-definitive-guide]: <https://www.kuppingercole.com/insights/identity-and-access-management/identity-access-management-guide> "KuppingerCole - The Definitive Guide to Identity & Access Management"
[kuppingercole-IGA-guide]: <https://www.kuppingercole.com/insights/identity-governance-and-administration/identity-governance-and-administration-guide> "KuppingerCole - Identity Governance and Administration – A Policy-Based Primer for Your Company"
[kuppingercole-website]: <https://www.kuppingercole.com/> "KuppingerCole Analysts AG"
[kuppingercole-zero-trust-guide]: <https://www.kuppingercole.com/insights/zero-trust/zero-trust-guide> "KuppingerCole - The Comprehensive Guide to Zero Trust Implementation"
[marisk-de]: <https://www.bafin.de/dok/16502162> "MaRisk - Mindestanforderungen an das Risikomanagement"
[marisk-en]: <https://www.bafin.de/dok/17832170> "MaRisk - Minimum Requirements for Risk Management"
[mica]: <https://www.esma.europa.eu/esmas-activities/digital-finance-and-innovation/markets-crypto-assets-regulation-mica> "Markets In Crypto-Assets Regulation (MiCA)"
[microsoft-remote-desktop]: <https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/remote-desktop-clients> "Microsoft Remote Desktop"
[microsoft-windows-app]: <https://learn.microsoft.com/windows-app> "Windows App"
[multipass]: <https://multipass.run/> "Canonical Multipass"
[nis2-explained]: <https://nis2directive.eu/> "The NIS2 Directive Explained"
[nis2-final]: <https://eur-lex.europa.eu/eli/dir/2022/2555/oj> "The Final NIS2 Legal Text"
[nist-oscal-workshops]: <https://pages.nist.gov/OSCAL/learn/presentations/mini-workshop/> "OSCAL Mini Workshop Series"
[nist-oscal]: <https://pages.nist.gov/OSCAL/> "OSCAL: the Open Security Controls Assessment Language"
[nist-scap]: <https://scap.nist.gov/> "SCAP - Security Content Automation Protocol"
[opa-website]: <https://www.openpolicyagent.org/> "Open Policy Agent"
[opal]: <https://github.com/permitio/opal> "Open Policy Administration Layer"
[open-scap]: <https://www.open-scap.org/> "OpenSCAP"
[trestle]: <https://github.com/IBM/compliance-trestle> "Trestle"
[virtualbox]: <https://www.virtualbox.org/> "VirtualBox"
[w3c-wai-act]: <https://www.w3.org/WAI/standards-guidelines/act/> "W3C - Accessibility Conformance Testing"
[w3c-wai-aria]: <https://www.w3.org/WAI/intro/aria> "W3C WAI - Accessible Rich Internet Applications"
[w3c-wai-earl]: <https://www.w3.org/WAI/intro/earl> "W3C WAI - Evaluation and Report Language"
[w3c-wai-policies]: <https://www.w3.org/WAI/policies/> "W3C WAI - Web Accessibility Laws & Policies"
[w3c-wai-wcag]: <https://www.w3.org/WAI/intro/wcag> "W3C WAI - Web Content Accessibility Guidelines"
[w3c-wai]: <https://www.w3.org/WAI/> "W3C Web Accessibility Initiative"
[xfce]: <https://www.xfce.org/> "Xfce Desktop Environment"
