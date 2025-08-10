# terraform-aws-bastion-openvpn

AWS에서 개인 또는 소규모 팀(5-10명)을 위한 Bastion 호스트와 OpenVPN 서버를 통합한 Terraform 모듈입니다.

## 특징

- 🚀 **단순한 단일 인스턴스 솔루션**: 하나의 EC2 인스턴스에서 Bastion과 OpenVPN 서버 제공
- 👥 **소규모 팀에 최적화**: 개인 개발자나 5-10명 팀을 위한 설계
- 💰 **비용 효율적**: 단일 t4g.nano 인스턴스로 월 ~3달러
- ⚡ **ARM64 전용**: 더 나은 가격 대비 성능을 위해 AWS Graviton (ARM64) 프로세서만 사용
- 🔒 **안전한 액세스**: Bastion SSH와 OpenVPN을 통한 안전한 원격 액세스
- 📊 **CloudWatch 통합**: 내장 모니터링 및 로깅
- 🎯 **간편한 설정**: 합리적인 기본값으로 간단한 구성
- 🔐 **자동 인증서 관리**: 지속적인 서비스를 위한 자동 인증서 갱신
- 📦 **S3 백엔드**: OpenVPN 구성 및 인증서를 위한 안전한 저장소
- 🐧 **Amazon Linux 2023**: 최신 Amazon Linux 2023 AMI 기반

## 빠른 시작

### 기본 사용법

```hcl
module "bastion_openvpn" {
  source = "./modules/bastion-openvpn"

  vpc_id    = "vpc-xxxxxxxxx"
  subnet_id = "subnet-xxxxxx"  # 단일 퍼블릭 서브넷

  tags = {
    Environment = "dev"
  }
}
```

### 소규모 팀을 위한 프로덕션 설정

```hcl
module "bastion_openvpn" {
  source = "./modules/bastion-openvpn"

  name      = "prod-bastion-vpn"
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnets[0]  # 단일 퍼블릭 서브넷에 배포

  # 인스턴스 설정 (t4g.nano는 5-10명 동시 사용자 지원)
  instance_type = "t4g.nano"  # 월 ~3달러, 가벼운 트래픽의 5-10명 사용자 처리
  key_name      = "my-key"

  # OpenVPN 액세스 제어
  openvpn_client_cidrs = ["1.2.3.4/32", "5.6.7.8/32"]  # 팀 IP로 제한

  # Bastion SSH 액세스 제어
  ssh_client_cidrs = ["1.2.3.4/32", "5.6.7.8/32"]  # SSH 액세스 제한

  # 모니터링
  enable_cloudwatch_alarms = true
  alarm_sns_topic_arn     = aws_sns_topic.alerts.arn

  # 인증서 관리
  enable_certificate_auto_renewal = true
  certificate_renewal_days        = 30

  tags = {
    Environment = "production"
    Team        = "DevOps"
  }
}
```

## 요구사항

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.0 |
| AMI | Amazon Linux 2023 (ARM64 전용) |
| 아키텍처 | ARM64/Graviton 전용 |

## 프로바이더

| Name | Version |
|------|---------|
| aws | ~> 5.0 |

## 입력 변수

### 필수 변수

| Name | Description | Type |
|------|-------------|------|
| vpc_id | VPC ID | string |
| subnet_id | Bastion 인스턴스를 위한 서브넷 ID | string |

### 선택 변수 (Optional Variables)

#### EC2 구성
| Name | Description | Type | Default |
|------|-------------|------|---------|
| name | 리소스 이름 prefix | string | "" (auto-generated) |
| vpc_cidr | 라우팅 및 VPN 구성을 위한 VPC CIDR 블록 | string | "10.0.0.0/16" |
| instance_type | EC2 인스턴스 타입 (ARM64/Graviton: t4g.* 필수) | string | "t4g.nano" |
| ami_id | 사용할 AMI ID | string | "" (최신 Amazon Linux 2023 ARM64) |
| key_name | EC2 키 페어 이름 | string | "" |
| enable_detailed_monitoring | 상세 모니터링 활성화 | bool | false |

#### EBS 구성
| Name | Description | Type | Default |
|------|-------------|------|---------|
| root_volume_size | 루트 볼륨 크기 (GB) | number | 20 |
| root_volume_type | 루트 볼륨 타입 | string | "gp3" |
| root_volume_encrypted | 루트 볼륨 암호화 | bool | true |
| root_volume_kms_key_id | KMS 키 ID | string | "" |

#### OpenVPN 구성
| Name | Description | Type | Default |
|------|-------------|------|---------|
| openvpn_port | OpenVPN 포트 | number | 1194 |
| openvpn_protocol | OpenVPN 프로토콜 | string | "udp" |
| enable_openvpn_tcp_fallback | TCP 폴백 활성화 | bool | true |
| openvpn_network | 클라이언트 네트워크 | string | "10.8.0.0" |
| openvpn_netmask | 넷마스크 | string | "255.255.255.0" |
| openvpn_netmask_bits | 넷마스크 비트 | number | 24 |
| openvpn_dns_servers | DNS 서버 | list(string) | ["8.8.8.8", "8.8.4.4"] |
| openvpn_client_cidrs | 접속 허용 CIDR | list(string) | ["0.0.0.0/0"] |
| openvpn_push_routes | 추가 라우트 | list(string) | [] |
| openvpn_cipher | 암호화 알고리즘 | string | "AES-256-GCM" |
| openvpn_auth | 인증 알고리즘 | string | "SHA256" |
| openvpn_compress | 압축 활성화 | bool | true |
| enable_ssh_from_vpn | VPN에서 SSH 허용 | bool | true |
| enable_client_to_client | VPN 클라이언트 간 통신 허용 | bool | false |
| allow_duplicate_cn | 동일한 인증서를 가진 여러 클라이언트 허용 | bool | false |
| ssh_client_cidrs | 직접 SSH 허용 CIDR (Bastion) | list(string) | [] |

#### S3 구성
| Name | Description | Type | Default |
|------|-------------|------|---------|
| create_s3_bucket | S3 버킷 생성 | bool | true |
| s3_bucket_name | S3 버킷 이름 | string | "" |

#### IAM 구성
| Name | Description | Type | Default |
|------|-------------|------|---------|
| iam_role_name | IAM 역할 이름 | string | "" (auto-generated) |
| iam_role_path | IAM 역할 경로 | string | "/" |
| iam_instance_profile_name | 인스턴스 프로파일 이름 | string | "" (auto-generated) |
| additional_iam_policy_arns | 추가 IAM 정책 ARN | list(string) | [] |
| additional_iam_policy_statements | 추가 IAM 정책 구문 | list(any) | [] |

#### Security Group 구성
| Name | Description | Type | Default |
|------|-------------|------|---------|
| security_group_name | 보안 그룹 이름 | string | "" (auto-generated) |
| additional_security_group_rules | 추가 보안 그룹 규칙 | list(object) | [] |

#### CloudWatch 구성
| Name | Description | Type | Default |
|------|-------------|------|---------|
| enable_cloudwatch_logs | CloudWatch 로그 활성화 | bool | true |
| cloudwatch_log_group_name | 로그 그룹 이름 | string | "" (auto-generated) |
| cloudwatch_log_retention_days | 로그 보관 기간 | number | 30 |
| cloudwatch_log_group_kms_key_id | KMS 키 ID | string | "" |
| enable_cloudwatch_alarms | CloudWatch 알람 활성화 | bool | false |
| alarm_sns_topic_arn | SNS 토픽 ARN | string | "" |
| openvpn_connection_alarm_threshold | 연결 수 알람 임계값 | number | 50 |

#### 인증서 갱신 구성
| Name | Description | Type | Default |
|------|-------------|------|---------|
| certificate_lifetime_days | 인증서 유효 기간 (일) | number | 365 |
| certificate_renewal_days | 만료 전 갱신 일수 | number | 30 |
| enable_certificate_auto_renewal | 자동 갱신 활성화 | bool | true |

#### 기타 구성
| Name | Description | Type | Default |
|------|-------------|------|---------|
| tags | 모든 리소스에 적용할 태그 | map(string) | {} |

전체 변수 목록은 [variables.tf](./variables.tf)를 참조하세요.

## 출력 값

| Name | Description |
|------|-------------|
| instance_id | EC2 인스턴스 ID |
| instance_public_ip | EC2 인스턴스 퍼블릭 IP |
| instance_private_ip | EC2 인스턴스 프라이빗 IP |
| elastic_ip | Elastic IP 주소 |
| security_group_id | 보안 그룹 ID |
| iam_role_arn | IAM 역할 ARN |
| iam_instance_profile_name | IAM 인스턴스 프로파일 이름 |
| s3_bucket_name | OpenVPN 구성을 위한 S3 버킷 이름 |
| s3_bucket_arn | OpenVPN 구성을 위한 S3 버킷 ARN |
| cloudwatch_log_group_name | CloudWatch 로그 그룹 이름 |
| openvpn_connection_info | OpenVPN 연결 정보 |
| ssh_connection_string | Bastion 액세스를 위한 SSH 연결 문자열 |
| generate_client_cert_command | OpenVPN 클라이언트 인증서 생성 명령 |
| certificate_renewal_settings | 인증서 갱신 구성 설정 |

## OpenVPN 클라이언트 설정

> **⏱️ Amazon Linux 2023에서의 설치 시간**
>
> OpenVPN은 소스에서 컴파일되므로 약 **5-10분**이 소요됩니다:
> - Development Tools 설치: 2-3분
> - OpenVPN 소스 다운로드: 30초
> - 컴파일: 2-3분
> - 설치 및 구성: 1-2분
>
> 진행 상황 모니터링: `sudo tail -f /var/log/user-data.log`

### 1. 클라이언트 인증서 생성

```bash
# Elastic IP를 사용하여 Bastion 인스턴스에 SSH 접속
ssh -i your-key.pem ec2-user@<elastic-ip>

# 클라이언트 설정 생성
sudo /usr/local/bin/generate-client-cert.sh client-name
```

### 2. 설정 파일 다운로드

```bash
# S3에서 다운로드
aws s3 cp s3://<bucket-name>/clients/client-name.ovpn .
```

### 3. OpenVPN 연결

#### macOS
```bash
brew install openvpn
sudo openvpn --config client-name.ovpn
```

#### Windows
1. [OpenVPN GUI](https://openvpn.net/client-connect-vpn-for-windows/) 설치
2. 설정 파일 임포트
3. 연결

#### Linux
```bash
sudo apt-get install openvpn
sudo openvpn --config client-name.ovpn
```

## 아키텍처

```
┌─────────────────────────────┐
│        Internet             │
└──────────┬──────────────────┘
           │
      [Elastic IP]
           │
    ┌──────┴──────┐
    │   Bastion   │
    │      +      │
    │   OpenVPN   │
    └──────┬──────┘
           │
    ┌──────┴──────┐
    │   Private   │
    │  Resources  │
    └─────────────┘
```

### 간단한 설계

- **단일 EC2 인스턴스**: 두 서비스를 실행하는 하나의 t4g.nano 인스턴스
- **Elastic IP**: 일관된 액세스를 위한 안정적인 퍼블릭 IP
- **이중 기능**: SSH bastion + OpenVPN 서버
- **S3 백엔드**: VPN 구성 및 인증서를 위한 안전한 저장소

## 비용 분석

| 구성 요소 | 월간 비용 | 세부 정보 |
|-----------|-----------|----------|
| EC2 인스턴스 (t4g.nano) | ~$3 | ARM 기반, 5-10명 사용자에 적합 |
| Elastic IP | $0 | 연결 시 무료 |
| EBS 스토리지 (20GB) | ~$1.60 | gp3 볼륨 |
| S3 스토리지 | <$1 | OpenVPN 구성 |
| **총합** | **~$5/월** | 개인 또는 소규모 팀에 적합 |

## 인스턴스 크기 권장사항

팀의 요구사항에 따라 적절한 인스턴스 크기를 선택하세요:

| 인스턴스 타입 | vCPUs | RAM | 최대 동시 사용자 | 사용 사례 | 월간 비용 |
|--------------|-------|-----|----------------|----------|----------|
| **t4g.nano** | 2 | 0.5GB | 5-10명 | 경량 관리 액세스, 소규모 팀 | ~$3 |
| **t4g.micro** | 2 | 1GB | 15-25명 | 일반 트래픽, 중간 규모 팀 | ~$6 |
| **t4g.small** | 2 | 2GB | 30-50명 | 중간 규모 사용, 대규모 팀 | ~$12 |
| **t4g.medium** | 2 | 4GB | 50-100명 | 높은 트래픽, 대규모 팀 | ~$24 |

> **중요**: 이 모듈은 AWS Graviton (ARM64) 인스턴스만 지원합니다. 모든 인스턴스 타입은 t4g, m6g, c6g, 또는 r6g 패밀리여야 합니다. x86 인스턴스는 지원되지 않습니다.

> **참고**: 사용자 제한은 일반적인 VPN 사용 패턴과 가벼운~중간 정도의 트래픽을 가정합니다. 대용량 데이터 전송이나 리소스 집약적인 작업에는 더 큰 인스턴스가 필요할 수 있습니다.

## 모니터링

### CloudWatch 메트릭

- CPU 사용률
- 메모리 사용률
- OpenVPN 연결 수
- 네트워크 트래픽

### 로그

- 시스템 로그: `/aws/ec2/<name>/system`
- OpenVPN 로그: `/aws/ec2/<name>/openvpn`

## 고급 기능

### 인증서 자동 갱신

OpenVPN 인증서를 자동으로 갱신하여 서비스 중단을 방지합니다.

```hcl
# 인증서 자동 갱신 설정
enable_certificate_auto_renewal = true
certificate_lifetime_days      = 365  # 인증서 유효 기간
certificate_renewal_days       = 30   # 만료 X일 전 갱신
```

특징:
- 매일 자동 확인 (Cron)
- 서버/클라이언트 인증서 모두 갱신
- CloudWatch 메트릭 및 알람
- S3 자동 백업

## 보안 고려사항

1. **접속 제한**: `openvpn_client_cidrs`를 특정 IP로 제한
2. **SSH Bastion 접속**: `ssh_client_cidrs`를 사용하여 직접 SSH 접속을 특정 IP로만 제한
3. **키 관리**: S3 버킷에 암호화 저장
4. **정기 업데이트**: AMI와 패키지 정기 업데이트
5. **모니터링**: CloudWatch 알람 설정
6. **인증서 관리**: 자동 갱신으로 만료 방지

## 중요 고려사항

### 운영체제

**이 모듈은 Amazon Linux 2023 (AL2023)을 사용합니다** - bastion/OpenVPN 인스턴스의 기본 AMI입니다.

### 간단한 배포

이 모듈은 직관적인 단일 인스턴스 배포를 생성합니다:

```hcl
# Bastion + OpenVPN 구성
module "bastion_openvpn" {
  source = "./modules/bastion-openvpn"

  vpc_id    = var.vpc_id
  subnet_id = var.public_subnet_id  # 단일 퍼블릭 서브넷

  # 선택사항: 액세스 제한
  openvpn_client_cidrs = ["1.2.3.4/32"]
  ssh_client_cidrs     = ["1.2.3.4/32"]
}
```

**제공 사항**:
- 1개의 EC2 인스턴스 (기본: t4g.nano)
- 안정적인 액세스를 위한 1개의 Elastic IP
- 적절한 규칙이 설정된 보안 그룹
- 구성을 위한 S3 버킷
- CloudWatch 로그 및 모니터링

## 정리

```bash
# 간단한 삭제 - 모든 리소스 제거
terraform destroy
```

## 문제 해결

### OpenVPN 연결 실패
```bash
# 보안 그룹 확인
aws ec2 describe-security-groups --group-ids <sg-id>

# 서비스 상태 확인
ssh ec2-user@<ip> "sudo systemctl status openvpn-server@server"
```

### SSH 연결 문제
```bash
# 인스턴스 상태 확인
aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].State'

# Elastic IP 확인
aws ec2 describe-addresses \
  --filters "Name=instance-id,Values=<instance-id>"

# 사용자 데이터 로그 보기
aws logs tail /aws/ec2/<name>/user-data --follow
```

## 사용 사례

### 적합한 경우:

- **개인 개발자**: 프라이빗 AWS 리소스에 안전한 액세스
- **소규모 팀 (5-10명)**: 가벼운 트래픽의 공유 Bastion 및 VPN 액세스
- **개발 환경**: 비용 효율적인 원격 액세스 솔루션
- **PoC**: 빠른 설정 및 테스트

### 권장하지 않는 경우:
- 대규모 팀 (AWS Client VPN 등 사용)
- 고가용성 프로덕션 환경
- 많은 동시 사용자 (>50명)

## 예제

- [간단한 설정](./examples/simple)
- [완전한 설정](./examples/complete)

## 기여하기

이슈와 PR을 환영합니다!

## 라이선스

Apache 2.0 License. [LICENSE](./LICENSE) 파일을 참조하세요.
