# Pandora monitoring scripts

Here you will find `.fcl` and `.xml` files for running the pandora moniting within LarSoft.
  
You can create a folder `config` anywhere you need, copy all files inside there and then execute:

``` bash
source setup_this_path.sh
```
This will setup so you can execute the next command from any directory.

You can run the visualization with:
  
``` bash
lar -c event_display_driver.fcl {YOUR_SAMPLE.root}
```

The `MyPandoraSettings_Master_Atmos_DUNEFD.xml` is set inside the `.fcl` file. This "master" configuration calls for `MyPandoraSettings_Neutrino_Atmos_DUNEFD.xml`
