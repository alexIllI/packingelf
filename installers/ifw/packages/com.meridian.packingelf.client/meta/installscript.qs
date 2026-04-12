function Component()
{
}

Component.prototype.createOperations = function()
{
    component.createOperations();

    if (systemInfo.productType !== "windows")
        return;

    var appDir = "@TargetDir@/PackingElf Client";
    var exePath = appDir + "/packingelf.exe";
    var startMenuLink = "@StartMenuDir@/包貨小精靈 Client.lnk";
    var desktopLink = "@DesktopDir@/包貨小精靈 Client.lnk";

    component.addOperation("CreateShortcut", exePath, startMenuLink,
        "workingDirectory=" + appDir,
        "description=包貨小精靈 Client");
    component.addOperation("CreateShortcut", exePath, desktopLink,
        "workingDirectory=" + appDir,
        "description=包貨小精靈 Client");
}
