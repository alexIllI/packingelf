function Component()
{
}

Component.prototype.createOperations = function()
{
    component.createOperations();

    if (systemInfo.productType !== "windows")
        return;

    var appDir = "@TargetDir@/PackingElf Host";
    var exePath = appDir + "/PackingElf Host.exe";
    var startMenuLink = "@StartMenuDir@/包貨小精靈 Host.lnk";
    var desktopLink = "@DesktopDir@/包貨小精靈 Host.lnk";

    component.addOperation("CreateShortcut", exePath, startMenuLink,
        "workingDirectory=" + appDir,
        "description=包貨小精靈 Host");
    component.addOperation("CreateShortcut", exePath, desktopLink,
        "workingDirectory=" + appDir,
        "description=包貨小精靈 Host");
}
