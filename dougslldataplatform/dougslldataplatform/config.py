import yaml


def config():
    with open('./resource/config.yaml', 'r') as arquivo:
        config = yaml.load(arquivo, Loader=yaml.FullLoader)
    return config
