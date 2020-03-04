namespace Core.Fake
{
    public class Command : ICommand
    {
        public Reader Reader { get; set; }
        public string CommandText { get; set; }

        public Command() {
            if (Reader == null)
                Reader = new Reader();
        }

        public IReader ExecuteReader() {
            return Reader;
        }
    }
}
