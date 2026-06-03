# profiles.dart replacements
with open("lib/views/profiles/profiles.dart", "r") as f:
    content = f.read()

content = content.replace('"${appLocalizations.add}${appLocalizations.profile}"', "appLocalizations.addProfile")
content = content.replace('"${appLocalizations.edit}${appLocalizations.profile}"', "appLocalizations.editProfile")
content = content.replace("return 'Unlimited';", "return '∞';")
content = content.replace("return '$useShow / Unlimited';", "return '$useShow / ∞';")

with open("lib/views/profiles/profiles.dart", "w") as f:
    f.write(content)

# controller.dart replacements
with open("lib/controller.dart", "r") as f:
    content = f.read()

content = content.replace('"${appLocalizations.add} ${appLocalizations.profile}"', "appLocalizations.addProfile")
content = content.replace('"${appLocalizations.add}${appLocalizations.profile}"', "appLocalizations.addProfile")
content = content.replace('"${appLocalizations.edit}${appLocalizations.profile}"', "appLocalizations.editProfile")

with open("lib/controller.dart", "w") as f:
    f.write(content)

# providers.dart replacements
with open("lib/views/proxies/providers.dart", "r") as f:
    content = f.read()

content = content.replace("return '$useShow / Unlimited';", "return '$useShow / ∞';")

with open("lib/views/proxies/providers.dart", "w") as f:
    f.write(content)

# requests.dart replacements
with open("lib/views/connection/requests.dart", "r") as f:
    content = f.read()

old_details = "appLocalizations.details(\n                                appLocalizations.request,\n                              )"
content = content.replace(old_details, "appLocalizations.requestDetails")
old_details_2 = "appLocalizations.details(\n                              appLocalizations.request,\n                            )"
content = content.replace(old_details_2, "appLocalizations.requestDetails")
old_details_3 = "appLocalizations.details(appLocalizations.request)"
content = content.replace(old_details_3, "appLocalizations.requestDetails")

with open("lib/views/connection/requests.dart", "w") as f:
    f.write(content)

# logs.dart replacements
with open("lib/views/logs.dart", "r") as f:
    content = f.read()

content = content.replace("appLocalizations.details(appLocalizations.log)", "appLocalizations.logDetails")

with open("lib/views/logs.dart", "w") as f:
    f.write(content)


# connections.dart replacements
with open("lib/views/connection/connections.dart", "r") as f:
    content = f.read()

content = content.replace("appLocalizations.details(appLocalizations.connection)", "appLocalizations.connectionDetails")
content = content.replace("appLocalizations.details(\n                                appLocalizations.connection,\n                              )", "appLocalizations.connectionDetails")
content = content.replace("appLocalizations.details(\n                              appLocalizations.connection,\n                            )", "appLocalizations.connectionDetails")

with open("lib/views/connection/connections.dart", "w") as f:
    f.write(content)

print("Applied Safe UI Updates")
