# Stayhome Devkit
AWS-based software development kit for remote worker

ソフトウェア開発をリモートで行うためのクラウドベースの開発環境をAWSのサービスで構築したものです。

コロナをきっかけとして急速に広まりつつある在宅勤務やテレワーク。

企業内でのオンプレミスでの環境でソフトウェアの開発、
突然の外出自粛で出社できず、企業内のオンプレミスで構築した開発環境を利用できず
ソフトウェア開発が止まってしまった方も多いのではないでしょうか。

これをきっかけに、クラウドベースの開発環境に移行しましょう。

## 機能
"StayHome DevKit" は、Linux ベースで複数人で行う開発に必ず必要な、以下のような機能を備えています。

* Ubuntu Linux環境 
* 共有ストレージ 
* git リポジトリ 

## インストール方法

### 準備
以下のものを前提とします。

* AWS アカウント
* AWS コマンドラインインターフェイス (AWS CLI) 
  - 最新バージョン (1.18.41以降）が必要です。
  - 管理者権限(各種リソースの作成が可能な状態）で動作するように設定してください。

* インストールする環境の固有名称の決定
    - [AWS S3 のBucket の命名ルール](
    https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-s3-bucket-naming-requirements.html)に従ってください。
        - 3 ～ 63 文字の長さで、小文字、数字、ピリオド、ダッシュのみ使用可
        - 銭湯は、小文字または数字
        - アンダースコア、末尾のダッシュ、連続するピリオド、隣接するピリオドとダッシュは使用不可
    - ユニークな、他になさそうな名称としてください。
        - そのままS3 のBucket 名称になります。"hello" のように、他で使われていそうなものを選択すると、インストールがエラーになります。

### 環境全体のインストール
上記で決定した固有名称を指定しシェルスクリプトを実行します。

```
$ ./create_base.sh <project_name>
```
インストール結果は、コマンドラインの出力と、AWS コンソールの"CloudFormatio" の画面でみることが出来ます。

## ユーザごとのLinux 環境のインストール

```
./create_base.sh <project_name> <user_name>
```

## 仕様

### 活用しているAWSサービス

* VPC 
 - Internet Gateway
 - Route Table
 - Subnet
 - VPC Endpoint
* S3
* EC2 
* CodeCommit (git リポジトリ)
* AWS Transfer for SFTP 
* CloudFormation 
* CloudWatch 
* IAM

### 全体像
<img alt="stayhome_overview.png" src="https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/211499/88fb1855-1aca-c83c-6b08-27f784b936e3.png">
