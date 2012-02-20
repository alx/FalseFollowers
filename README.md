# Twitter bot detector

Following the news about possible bot creation on some political twitter account - http://reflets.info/les-blackops-de-lump-au-travail-et-ca-se-voit/ - I wanted to create a tools to detect this beahavior.

This script will detect follower intersection on different account, and
then analyse these followers.

The goal of this script will be to detect:

* mass creation of accounts
* networks of strange accounts
* strategies in place to hide this kind of activity

# Usage

After filling the screen names of the twitter accounts you want to
follow, execute the script:

    ruby followers.rb

A csv file will be created with common followers from all accounts.
