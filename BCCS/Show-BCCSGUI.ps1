function Show-BCCSWPFGUI {
        Add-Type -AssemblyName PresentationFramework

        [xml]$XAML = @"
<Window
xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
xmlns:System="clr-namespace:System;assembly=mscorlib"
Title="Business Central Container Script" Height="500" Width="840" MinWidth="840" MinHeight="500">
<DockPanel LastChildFill="True" Margin="10">
<TreeView Name="treeContainers" Width="320" Margin="10,10,0,10"/>
<TabControl Margin="10" >
<TabItem Header="Commands">
<Grid Background="#FFE5E5E5" Margin="10,10,0,27">
<ListBox Margin="10,10,10,0" RenderTransformOrigin="0.501,0.594" Height="117" VerticalAlignment="Top"/>
<DataGrid Margin="10,132,10,0" Height="164" VerticalAlignment="Top">
<DataGrid.Columns>
<DataGridCheckBoxColumn/>
<DataGridTextColumn Header="Parameter" IsReadOnly="True" Width="128"/>
<DataGridTextColumn Header="Value" Width="256"/>
</DataGrid.Columns>
</DataGrid>
<WrapPanel Height="53" Margin="10,301,10,0" VerticalAlignment="Top">
<Button Content="Execute" Width="75"/>
</WrapPanel>
</Grid>
</TabItem>
</TabControl>
</DockPanel>
</Window>
"@ -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
        
        [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
        try {
                $Form = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $XAML) )
        }
        catch {
                throw "Windows.Markup.XamlReader could not be loaded"
        }

        $treeContainers = $Form.FindName('treeContainers')

        $allTemplates = Get-BCCSTemplate

        foreach ( $template in $allTemplates ) { 			
                Add-TreeItem -Name $template.prefix -Header ($template.name + " (" + $template.prefix + ")")  -Parent $treeContainers -Tag "Root"																						
                #$templateNode = New-Object System.Windows.Forms.TreeNode
                #$templateNode.text = $template.Prefix + " (" + $template.Name + ")"
                #$templateNode.name = $template.Prefix
                #$templateNode.Checked = $false
                #$templateContainers = Get-DockerContainer | Where-Object Name -Match ($template.Prefix + "-")
                #foreach ($container in $templateContainers) {
                #        $containerNode = New-Object System.Windows.Forms.TreeNode
                #        $containerNode.text = $container.Name
                #        if ((Get-DockerContainerStatus -Name $container.Name) -match "running") {
                #                $containerNode.ForeColor = "#369219"
                #        }
                #        else {
                #                $containerNode.ForeColor = "#921A19"
                #        }
                #        $templateNode.Nodes.Add($containerNode)
                #}
                #$TreeView.Nodes.Add($templateNode)
        }

        $Form.ShowDialog()
}

Function Add-TreeItem {
        Param(
                $Header,
                $Name,
                $Parent,
                $Tag
        )

        $ChildItem = New-Object System.Windows.Controls.TreeViewItem
        $ChildItem.Header = $Header
        $ChildItem.Name = $Name
        $ChildItem.Tag = "$Tag\$Name"
        [Void]$ChildItem.Items.Add("*")
        [Void]$Parent.Items.Add($ChildItem)
}

Export-ModuleMember -Function Show-BCCSGUI