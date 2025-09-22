
# 목차

- [사용 가이드](#사용-가이드)
  - [기본 명령어](#기본-명령어)
  - [고급 옵션](#고급-옵션)
  - [모듈 세부사항](#모듈-세부사항)
  - [사용자 워크플로우](#사용자-워크플로우)
    - [1단계: Root로 초기 설정 실행](#1단계-root로-초기-설정-실행)
    - [2단계: 개발 사용자로 전환](#2단계-개발-사용자로-전환)
    - [3단계: 사용자로 설정 계속](#3단계-사용자로-설정-계속)
    - [파일 위치](#파일-위치)
    - [권한 시스템](#권한-시스템)
  - [구성](#구성)
    - [1. 구성 파일 편집](#1-구성-파일-편집)
    - [2. 환경 변수 사용](#2-환경-변수-사용)
  - [예제](#예제)
    - [전체 환경 설정](#전체-환경-설정)
    - [Dockerfile 통합](#dockerfile-통합)
  - [환경 매니저: 선택 및 권한](#환경-매니저-선택-및-권한)
  - [문제 해결](#문제-해결)
    - [poetry: command not found (127)](#poetry-command-not-found-127)
    - [다른 사용자에 대한 권한 거부 또는 액세스 누락](#다른-사용자에-대한-권한-거부-또는-액세스-누락)
    - [SSH 권한 문제](#ssh-권한-문제)
    - [환경 매니저 설치 실패](#환경-매니저-설치-실패)
    - [로케일 구성 문제](#로케일-구성-문제)
    - [사용자 전환 문제](#사용자-전환-문제)
    - [APT 소스 문제](#apt-소스-문제)
    - [로그 파일 확인](#로그-파일-확인)
    - [권한 재설정](#권한-재설정)
  - [추가 리소스](#추가-리소스)
    - [구성 파일 위치](#구성-파일-위치)
    - [유용한 명령어](#유용한-명령어)
    - [지원 및 문의](#지원-및-문의)



# 사용 가이드

이 가이드는 고급 옵션, 모듈 세부사항, 구성을 포함하여 `ml-dev-bootstrap` 유틸리티 사용 방법에 대한 자세한 정보를 제공합니다.

---

## 기본 명령어

환경 설정을 위한 가장 일반적인 명령어들입니다.

```bash
# 대화형 메뉴를 사용하여 모든 설정 모듈 실행
sudo ./setup.sh --menu

# 진행률 표시줄과 함께 모든 모듈을 비대화형으로 실행
sudo ./setup.sh --all --progress

# 특정 모듈만 실행
sudo ./setup.sh system git locale
```

-----

## 고급 옵션

이러한 플래그로 스크립트의 동작을 세밀하게 조정할 수 있습니다.

| 플래그 | 설명 | 예제 |
| :--- | :--- | :--- |
| `--dry-run` | 실행하지 않고 모든 변경사항을 미리 봅니다. | `sudo ./setup.sh --all --dry-run` |
| `--diagnose` | 모든 모듈에 대한 진단 검사를 실행합니다. | `sudo ./setup.sh --diagnose` |
| `--list` | 사용 가능한 모든 모듈 목록을 표시합니다. | `./setup.sh --list` |
| `--switch-user` | 계속된 설정을 위해 개발 사용자로 전환합니다. | `sudo ./setup.sh --switch-user` |
| `--verbose` | 디버깅을 위한 자세한 상세 로깅을 활성화합니다. | `sudo ./setup.sh --verbose system` |
| `--update` | 각 모듈 내에서 업데이트 기능을 실행합니다. | `sudo ./setup.sh --update` |
| `--backup` | 주요 구성 파일의 백업을 생성합니다. | `sudo ./setup.sh --backup` |

-----

## 모듈 세부사항

  - **`system`**: 필수 개발 패키지와 빌드 도구(`git`, `vim`, `gcc` 등)를 설치하고 시스템을 업데이트합니다.
  - **`locale`**: `en_US.UTF-8`과 `ko_KR.UTF-8`에 중점을 둔 시스템 전체 로케일을 구성합니다. 필요한 폰트를 설치합니다.
  - **`user`**: 적절한 권한과 홈 디렉토리 구조를 가진 전용 개발 사용자 및 그룹을 생성합니다.
  - **`sources`**: 더 빠른 패키지 다운로드를 위해 지역 미러(Kakao, Naver, Daum 등)를 사용하도록 APT 소스를 구성합니다.
  - **`conda`**: Conda(Micromamba) 설치를 감지하고 업데이트하며, 채널을 구성하고 사용자 권한을 설정합니다.
  - **`envmgr`**: 다중 사용자 dev-그룹 권한을 가진 conda/micromamba, pyenv, poetry, pipenv용 대화형 설치 프로그램입니다.
  - **`git`**: 사용자 정보, 기본 브랜치 이름, 유용한 별칭을 포함한 전역 git 설정을 구성합니다.
  - **`prompt`**: 현재 git 브랜치와 conda 환경을 표시하는 현대적이고 정보가 풍부한 셸 프롬프트를 설정합니다.

-----

## 사용자 워크플로우

스크립트는 사용자 생성과 권한 위임을 적절히 처리하도록 설계되었습니다:

### 1단계: Root로 초기 설정 실행
```bash
sudo ./setup.sh --all  # 또는 특정 모듈 실행
```

### 2단계: 개발 사용자로 전환
사용자를 생성한 후, 개발 사용자 계정으로 전환합니다:
```bash
sudo ./setup.sh --switch-user
# 또는 수동으로: su - vscode
```

### 3단계: 사용자로 설정 계속
개발 사용자로 전환한 후, 사용자별 설치를 계속합니다:
```bash
# 홈 디렉토리의 편리한 심볼릭 링크 사용
cd ~/setup && ./setup.sh --menu

# 또는 메인 위치로 이동
cd /opt/ml-dev-bootstrap && ./setup.sh --menu
```

### 파일 위치
설정 파일들은 최적의 액세스를 위해 전략적으로 배치되어 있습니다:
- **메인 위치**: `/opt/ml-dev-bootstrap` (최적의 권한)
- **사용자 심볼릭 링크**: `~/setup` (편리한 액세스)
- **호환성**: `/root/ml-dev-bootstrap` (기존 스크립트용 심볼릭 링크)

### 권한 시스템
- **그룹 기반 액세스**: 모든 설정 파일이 `root:dev` 그룹 소유
- **Setgid 디렉토리**: 새 파일이 dev 그룹 소유권을 상속
- **다중 사용자 지원**: 개발 사용자가 설정 파일을 읽기/쓰기 가능
- **유연한 Root 요구사항**: 시스템 작업은 root 필요, 사용자 작업은 사용자로 실행 가능

-----

## 구성

스크립트를 두 가지 주요 방법으로 구성할 수 있습니다:

#### 1\. 구성 파일 편집

가장 간단한 방법은 `config/defaults.conf` 파일을 직접 편집하는 것입니다.

```bash
# config/defaults.conf의 예제 스니펫

# 사용자 구성
USERNAME=devuser
USER_GROUP=dev

# Git 구성
GIT_USER_NAME="Developer"
GIT_USER_EMAIL="dev@example.com"
```

#### 2\. 환경 변수 사용

임시 변경이나 CI/CD 환경에서 사용하기 위해 환경 변수로 설정을 재정의할 수 있습니다. 변수를 root 환경에 전달하려면 `sudo -E`를 사용해야 합니다.

```bash
# git 사용자를 재정의하고 git 모듈을 실행하는 예제
export GIT_USER_NAME="Jane Doe"
export GIT_USER_EMAIL="jane.doe@example.com"
sudo -E ./setup.sh git
```

-----

## 예제

#### 전체 환경 설정

사용자 정의 사용자와 git 신원을 설정한 후 전체 설정을 실행합니다.

```bash
export USERNAME=jdoe
export GIT_USER_NAME="Jane Doe"
export GIT_USER_EMAIL="jane.doe@example.com"
sudo -E ./setup.sh --all --progress
```

#### Dockerfile 통합

스크립트를 사용하여 개발 컨테이너를 프로비저닝합니다.

```dockerfile
FROM ubuntu:22.04

COPY ml-dev-bootstrap /opt/ml-dev-bootstrap
WORKDIR /opt/ml-dev-bootstrap

# 비대화형으로 설정 실행
RUN ./setup.sh --all

# 새 사용자로 전환
USER devuser
WORKDIR /home/devuser
CMD ["/bin/bash"]
```

-----

## 환경 매니저: 선택 및 권한

메뉴에서 옵션 `e`로 실행한 후 하나 이상의 매니저를 선택합니다:

```
1) conda
2) micromamba
3) pyenv
4) poetry
5) pipenv
6) uv
```

동작 및 위치:
- Poetry: dev-그룹 권한을 가진 `/opt/pypoetry`에 시스템 전체 설치(기본값); `/usr/local/bin/poetry`에 shim.
- Pyenv: 구성된 사용자(USERNAME) 또는 root용으로 설치; dev-그룹 권한 적용; `/usr/local/bin/pyenv`에 shim.
- Pipenv: dev-그룹 권한을 가진 사용자별 설치; `/usr/local/bin/pipenv`에 선택적 shim.
- UV: 빠른 Python 패키지 설치 및 해결을 위한 사용자 기반 설치.

PATH는 `/usr/local/bin`, `/opt/pypoetry/bin`, `$HOME/.local/bin`을 추가하는 `/etc/profile.d/ml-dev-tools.sh`를 통해 세션 전반에 걸쳐 보장됩니다.

-----

## 문제 해결


### poetry: command not found (127)

`poetry`가 방금 설치되었는데 셸이 여전히 127을 반환하는 경우, 셸을 새로 고침하세요:

```bash
hash -r
exec $SHELL -l
poetry --version
```

shim이 존재하고 올바른 대상을 가리키는지 확인하세요:

```bash
readlink -f /usr/local/bin/poetry
ls -l /opt/pypoetry/bin
```

### 다른 사용자에 대한 권한 거부 또는 액세스 누락

dev 그룹이 존재하고 디렉토리가 setgid로 그룹 쓰기 가능한지 확인하세요:

```bash
getent group dev
ls -ld /opt/pypoetry /opt/pypoetry/bin /opt/pypoetry/venv
```

### SSH 권한 문제

SSH 키와 구성 파일의 권한이 올바르지 않은 경우:

```bash
# 메뉴에서 SSH 권한 수정 옵션 사용
sudo ./setup.sh --menu
# 그런 다음 'p) SSH 권한 수정' 선택

# 또는 직접 SSH 모듈 실행
sudo ./setup.sh ssh
```

### 환경 매니저 설치 실패

특정 환경 매니저 설치가 실패하는 경우:

```bash
# 상세 로깅으로 진단 실행
sudo ./setup.sh --verbose --diagnose

# 특정 환경 매니저만 다시 설치
sudo ./setup.sh envmgr
```

### 로케일 구성 문제

로케일이 올바르게 설정되지 않은 경우:

```bash
# 현재 로케일 상태 확인
locale -a
localectl status

# 로케일 모듈 다시 실행
sudo ./setup.sh locale
```

### 사용자 전환 문제

개발 사용자로 전환할 수 없는 경우:

```bash
# 사용자가 존재하는지 확인
id vscode  # 또는 구성된 사용자명

# 사용자 모듈 다시 실행
sudo ./setup.sh user

# 수동으로 사용자 전환 시도
sudo su - vscode
```

### APT 소스 문제

패키지 다운로드가 느리거나 실패하는 경우:

```bash
# 소스 모듈을 실행하여 더 빠른 미러 선택
sudo ./setup.sh sources

# 또는 메뉴에서 빠른 작업으로 실행
sudo ./setup.sh --menu
# 그런 다음 's) APT 소스 구성' 선택
```

### 로그 파일 확인

문제 진단을 위해 로그 파일을 확인하세요:

```bash
# 기본 로그 위치
tail -f /var/log/ml-dev-bootstrap.log

# 상세 로깅 활성화
sudo ./setup.sh --verbose [모듈명]
```

### 권한 재설정

설정 디렉토리 권한을 재설정해야 하는 경우:

```bash
# 사용자 모듈을 다시 실행하여 권한 수정
sudo ./setup.sh user

# 또는 수동으로 권한 설정
sudo chown -R root:dev /opt/ml-dev-bootstrap
sudo chmod -R g+w /opt/ml-dev-bootstrap
sudo find /opt/ml-dev-bootstrap -type d -exec chmod g+s {} \;
```

---

## 추가 리소스

### 구성 파일 위치
- **메인 구성**: `/opt/ml-dev-bootstrap/config/defaults.conf`
- **로그 파일**: `/var/log/ml-dev-bootstrap.log`
- **백업 디렉토리**: `/opt/ml-dev-bootstrap/backups/`

### 유용한 명령어
```bash
# 모든 설치된 환경 매니저 확인
which python3 pip3 conda micromamba pyenv poetry pipenv uv

# 현재 사용자 및 그룹 확인
id
groups

# 설정 디렉토리 권한 확인
ls -la /opt/ml-dev-bootstrap
ls -la ~/setup
```

### 지원 및 문의
문제가 지속되는 경우 다음을 확인하세요:
1. 로그 파일에서 오류 메시지 확인
2. `--diagnose` 플래그로 시스템 상태 확인
3. `--dry-run` 플래그로 변경사항 미리 보기
4. `--verbose` 플래그로 상세한 디버그 정보 확인
