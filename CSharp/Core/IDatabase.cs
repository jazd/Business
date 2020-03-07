using System;
namespace Business.Core
{
    public interface IDatabase
    {
        IConnection Connection { get; set; }
        ICommand Command { get;}

        void Connect();
        Version SchemaVersion();
    }
}
