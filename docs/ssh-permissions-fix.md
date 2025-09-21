
# SSH 권한 수정 유틸리티

일반적인 SSH 권한 문제를 해결하는 독립형 스크립트로, 컨테이너에 연결하는 WSL 사용자에게 특히 유용합니다.

## 사용 사례

이 유틸리티는 SSH 권한 불일치가 자주 발생하는 컨테이너화된 환경이나 WSL 환경에서 작업하는 개발자에게 필수적입니다. "Permission denied (publickey)" 오류가 발생하거나, 시스템 간에 SSH 키를 복사한 후, 또는 새로운 개발 환경을 설정할 때 안전하고 기능적인 SSH 연결을 보장하기 위해 사용하세요.

## 빠른 시작

```bash
# 기본 SSH 디렉토리(~/.ssh)의 권한 수정
./utils/fix-ssh-permissions.sh

# 사용자 정의 SSH 디렉토리의 권한 수정
./utils/fix-ssh-permissions.sh /home/user/.ssh

# 도움말 표시
./utils/fix-ssh-permissions.sh --help

# 드라이런 (변경될 내용 표시)
./utils/fix-ssh-permissions.sh --dry-run
```

## 수정하는 내용

- **SSH 디렉토리 권한** (700)
- **개인 키 권한** (600)
- **공개 키 권한** (644)
- **authorized_keys 권한** (600)
- **SSH config 권한** (600)
- **known_hosts 권한** (644)
- **WSL 특정 권한 문제**

## 통합

이 스크립트는 다음에 자동으로 통합됩니다:

1. **SSH 모듈**: SSH 설정 중 자동으로 실행
2. **대화형 메뉴**: 빠른 작업 "p) SSH 권한 수정"으로 사용 가능

## 해결되는 일반적인 문제

### WSL에서 컨테이너 연결
```bash
# 이전: Permission denied (publickey)
# 이후: 깔끔한 SSH 연결
ssh container
```

### 권한 오류
```bash
# 이전: Bad permissions for ~/.ssh/id_rsa
# 이후: 올바른 600 권한
ls -la ~/.ssh/id_rsa  # -rw------- 1 user user
```

### 다중 사용자 환경
```bash
# 특정 사용자의 권한 수정
sudo -u username ./utils/fix-ssh-permissions.sh
```

## 수동 사용

권한을 수동으로 수정하려는 경우:

```bash
# 디렉토리 권한 수정
chmod 700 ~/.ssh

# 개인 키 권한 수정
chmod 600 ~/.ssh/id_*

# 공개 키 권한 수정
chmod 644 ~/.ssh/*.pub

# authorized_keys 수정
chmod 600 ~/.ssh/authorized_keys
```
