# Jeff
Jeff is a easy to use, efficient, and extensible bot for Discord using the [dscord](https://github.com/b1naryth1ef/dscord) library.

## Building Jeff
Building jeff is a fairly simple process, which requires at most a valid D compiler, and a working version of the dscord library. Once you've acquired those, you can run the following command to build the base bot:

```sh
./build.py
```

You should now have a `jeff` binary which can be run with a valid bot token.

### With Plugins
To build some plugins along with jeff, you can add the `--plugin` flag to the build script with a valid Github repo path, for instance most users will likely want to build jeff like so:

```sh
./build.py --plugin b1naryth1ef/jeff-core --plugin b1naryth1ef/jeff-msglog --plugin b1naryth1ef/jeff-mod
```

## Running Jeff
The Jeff binary can be started by simply including the token flag, like so:

```sh
./jeff --token=MY_DISCORD_BOT_TOKEN
```

