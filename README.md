# Blog starter ❦

# What you'll need (aside from this repo)

 - A GitHub account
 - A 'classic' GitHub Personal Access Token
 - An AWS account
 - A domain name managed and purchased with the Amazon registrar, Route53. If
 you don't have this, or your domain is with someone else, please import it
 before continuing. Yes, I know this costs money and is annoying, but it's
 table stakes.


# Prelims

We use Nix for a lot of stuff, so start by installing Nix, if you've never done so already. You'll need Linux, MacOS or Windows + WSL2 (Linux)

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate
```

Once `nix` is installed, you can use it to enter a development shell that will be populated with the correct versions all the tools you need. You can see your options:

```bash
./just # this will show a list of possible commands
```

For most work, you'll want to get inside the shell because it's convenient and nice:

```bash
./just shell #calls `nix develop` under the hood
```

Once you're inside the shell you can drop the `./` from in front of `just`.

Now, once you're inside the shell, and if this is a freshly cloned repo:

```bash

just setup # this installs git hooks and some other stuff

```

Now you'll want to add your details to the `.env` file. You can start by `cp env.example .env`

Edit this file until it is correct.


Now:

```bash

just deploy

```

You will be asked if you wish to proceed. If you say 'yes', Amplify will be automatically configured with a custom build image (makes it very snappy and cheap)

You'll see a bunch of crazy stuff happen. When the smoke clears, any further push to the main branch of this repo will result in an automated redeployment.
Which is to say, mostly, you don't need to run `just deploy`; a simple `git push` will do the same thing. You don't even need to be in the development shell!

So your typical workflow might be:

```bash
cd <this directory>
nvim content/posts/2025-07-25-foo.md
git commit -am 'feat: more blog content'
git push
```

And your changes will show up on internet at your specified domain.

