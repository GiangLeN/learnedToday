## Create keygen using email
```
ssh-keygen -t ed25519 -C "email@.com"
```
### Enter passphrase

Evaluate ssh-agent
```
eval "$(ssh-agent -s)"
```
## Add key
```
ssh-add ~/.ssh/id_ed2551
```

## Check key
```
less /home/vdsa/.ssh/id_ed25519.pub
```

Pastes this key to Setting > SSH and GPG keys


Setup with git
git config --global user.email "email@.com"

git config --global user.name "User_name"
