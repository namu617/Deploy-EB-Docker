# Dockerfile.dev를 작성 (Dockerfile.local을 복붙, local도 경로 수정)
#설정모듈은 config.settings.dev 사용
#uWSGI로 전달할 WSGI모듈은 wsgi.dev 사용
#.config/nginx, .config/uwsgi, .config/supervisor
#    각 폴더 내부에 'dev'폴더 생성 후 설정 복사 및 경로 변경
#
#docker build ...(옵션)을 이용해 'eb-dev'이미지를 생성 후 실행
#
#
#RDS, S3 관련하여 보안그룹(Security Group)설정이 필요할 경우 AWS콘솔에서 실행


# 1. config/local내부의 모든 내용을 .config/dev로 복사
#   1-1. 각 설정파일들에서 config.settings.local을 사용하는 부분들을
#           전부 config.settings.dev를 사용하도록 교체
#   1-2. 각 설정파일들에서 config.wsgi.local을 사용하는 부분들을 config.wsgi.dev로 교체
# 2. Dockerfile.local.local의 내용을 dev로 복사
# 위와 같이 설정
# 3. Dockerfile.local.dev에 있는 내용을 'base'이미지에서 직접 실행해보며 동작하는지 확인
#       확인된 것만 남기고 수정해야 될 부분은 Dockerfile.local.dev에서 수정
#       docker run --rm -it -p 8012:8000 base /bin/zsh
#       docker cp <origin <contiainer_id>:<path>
# 4. runserver에서 RDS와 S3가 동작하는지 확인 (settings.dev모듈에서 print문 사용)

#    export DJANGO_SETTINGS_MODULE=config.settings.dev
#    ./manage.py runserver 0:8000

#   DJANGO_SETTINGS_MODULE=config.settings.dev ./manage.py <command>

#   (settings/dev.py) pprint(DATABASES)
#   실제 데이터들이 S3, RDS에 들어있는지 확인 (AWS Console, psql)




# 5. uWSGI를 http모드로 실행해서 (--http :8000) Django와 잘 연결되는지 외부포트(8012)로 확인
# 6. Nginx를 실행해서 외부포트(8013)으로 접속했을때 Nginx가 동작하는지 (uWSGI를 켜지 않았다면 502에러) 확인
# 7. uWSGI와 Nginx
FROM        viking617/base
MAINTAINER  viking617617@gmail.com

ENV         LANG C.UTF-8
ENV         DJANGO_SETTINGS_MODULE config.settings.dev

# 파일 복사 및 requirements 설치
COPY        . /srv/app
RUN         /root/.pyenv/versions/app/bin/pip install -r /srv/app/requirements.txt

# pyenv local 설정
WORKDIR     /srv/app
RUN         pyenv local app

# Nginx
RUN         cp /srv/app/.config/dev/nginx/nginx.conf /etc/nginx/nginx.conf
RUN         cp /srv/app/.config/dev/nginx/app.conf \
                /etc/nginx/sites-available
RUN         rm -rf /etc/nginx/sites-enabled/*
RUN         ln -sf /etc/nginx/sites-available/app.conf \
                    /etc/nginx/sites-enabled/app.conf

# uWSGI
RUN         mkdir -p /var/log/uwsgi/app


# manage.py
WORKDIR     /srv/app/mysite
RUN         /root/.pyenv/versions/app/bin/python manage.py collectstatic --noinput
RUN         /root/.pyenv/versions/app/bin/python manage.py migrate --noinput


# supervisor
RUN         cp /srv/app/.config/dev/supervisor/* \
                /etc/supervisor/conf.d/
CMD         supervisord -n

EXPOSE      80